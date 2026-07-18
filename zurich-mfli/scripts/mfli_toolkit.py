#!/usr/bin/env python3
"""Read-only-first MFLI adapter using the official zhinst-toolkit package."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

import numpy as np
from zhinst import core
from zhinst.toolkit import Session


def jsonable(value: Any) -> Any:
    if isinstance(value, dict):
        return {str(key): jsonable(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [jsonable(item) for item in value]
    if isinstance(value, np.ndarray):
        return jsonable(value.tolist())
    if isinstance(value, np.generic):
        return value.item()
    return value


def emit(value: Any) -> None:
    print(json.dumps(jsonable(value), indent=2, sort_keys=True))


def discoveries() -> list[dict[str, Any]]:
    discovery = core.ziDiscovery()
    result = []
    for serial in discovery.findAll():
        info = discovery.get(serial)
        if info["devicetype"] != "MFLI":
            continue
        result.append(
            {
                "device": info["deviceid"].upper(),
                "device_type": info["devicetype"],
                "server_address": info["serveraddress"],
                "server_port": int(info["serverport"]),
                "api_level": int(info["apilevel"]),
                "interfaces": info["interfaces"],
                "connected": info["connected"],
                "available": info["available"],
                "owner": info["owner"],
                "status": info["status"],
                "firmware_revision": int(info["firmwarerev"]),
            },
        )
    return result


def select_device(requested: str | None) -> dict[str, Any]:
    records = discoveries()
    if requested:
        serial = requested.upper()
        matches = [record for record in records if record["device"] == serial]
        if len(matches) != 1:
            raise RuntimeError(f"MFLI device {serial} was not found.")
        return matches[0]
    if not records:
        raise RuntimeError("No MFLI device was found by LabOne discovery.")
    if len(records) > 1:
        raise RuntimeError("Multiple MFLI devices found; specify --device.")
    return records[0]


def open_session(record: dict[str, Any], args: argparse.Namespace) -> Session:
    host = args.server_host or record["server_address"]
    port = args.port or record["server_port"]
    return Session(host, port, allow_version_mismatch=True)


def base_result(record: dict[str, Any], session: Session) -> dict[str, Any]:
    client_version = core.__version__
    server_version = session.daq_server.getString("/zi/about/version")
    return {
        "device": record["device"],
        "host": session.server_host,
        "port": session.server_port,
        "client_version": client_version,
        "server_version": server_version,
        "version_match": client_version == server_version,
    }


def parse_value(raw: str) -> Any:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def resolve_node(device: Any, serial: str, raw_path: str) -> Any:
    prefix = f"/{serial.lower()}"
    path = raw_path.lower()
    if not path.startswith(f"{prefix}/"):
        raise RuntimeError(f"Node must belong to {serial}: {raw_path}")
    return device.root.raw_path_to_node(path[len(prefix) :])


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("discover", "status", "read", "sample", "write"))
    parser.add_argument("--device")
    parser.add_argument("--node")
    parser.add_argument("--value")
    parser.add_argument("--demod", type=int, default=0)
    parser.add_argument("--server-host")
    parser.add_argument("--port", type=int)
    parser.add_argument("--allow-write", action="store_true")
    parser.add_argument("--confirm-device")
    parser.add_argument("--allow-version-mismatch", action="store_true")
    args = parser.parse_args()

    try:
        if args.command == "discover":
            emit({"operation": "discover", "toolkit_version": core.__version__, "devices": discoveries()})
            return 0

        record = select_device(args.device)
        session = open_session(record, args)
        try:
            result = {"operation": args.command, **base_result(record, session)}
            device = session.devices[record["device"].lower()]
            if args.command == "status":
                result.update(
                    {
                        "device_type": device.device_type,
                        "visible_devices": session.devices.visible(),
                        "connected_devices": list(session.devices),
                        "discovery": record,
                    },
                )
            elif args.command == "read":
                if not args.node:
                    raise RuntimeError("read requires --node.")
                node = resolve_node(device, record["device"], args.node)
                result.update({"node": str(node), "value": node()})
            elif args.command == "sample":
                if not 0 <= args.demod <= 7:
                    raise RuntimeError("demod must be between 0 and 7.")
                result.update({"node": f"/{record['device']}/demods/{args.demod}/sample", "sample": device.demods[args.demod].sample()})
            elif args.command == "write":
                if not args.node or args.value is None:
                    raise RuntimeError("write requires --node and --value.")
                if "*" in args.node or "?" in args.node:
                    raise RuntimeError("Wildcard writes are prohibited.")
                if not args.allow_write:
                    raise RuntimeError("Write blocked: pass --allow-write after explicit user confirmation.")
                if args.confirm_device != record["device"]:
                    raise RuntimeError(f"Write blocked: --confirm-device must equal {record['device']}.")
                if not result["version_match"] and not args.allow_version_mismatch:
                    raise RuntimeError("Write blocked: toolkit and Data Server versions differ.")
                node = resolve_node(device, record["device"], args.node)
                old_value = node()
                node(parse_value(args.value))
                result.update({"node": str(node), "old_value": old_value, "readback_value": node()})
            emit(result)
        finally:
            session.daq_server.disconnect()
        return 0
    except Exception as error:  # CLI boundary: always return machine-readable errors.
        emit({"success": False, "error": str(error)})
        return 1


if __name__ == "__main__":
    sys.exit(main())
