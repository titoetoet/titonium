#!/usr/bin/env python3
"""Run the Draft 2020-12 keywords used by Titonium's shipped settings schema."""

from __future__ import annotations

import copy
import ast
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "config/schemas/settings.schema.json"
DEFAULTS_PATH = ROOT / "config/defaults/settings.json"
V7_FIXTURE_PATH = ROOT / "tests/fixtures/settings-v7-runtime.json"
VALIDATOR_PATH = ROOT / "scripts/validate_config.py"


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def type_matches(value: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    raise ValueError(f"unsupported JSON Schema type: {expected}")


def validate(value: Any, schema: dict[str, Any], path: str = "$") -> list[str]:
    """Evaluate the standard JSON Schema keywords used by settings.schema.json."""
    errors: list[str] = []
    expected_type = schema.get("type")
    if expected_type is not None and not type_matches(value, expected_type):
        return [f"{path}: expected {expected_type}"]
    if "const" in schema and value != schema["const"]:
        errors.append(f"{path}: must equal {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: must be one of {schema['enum']!r}")
    if isinstance(value, str) and "minLength" in schema and len(value) < schema["minLength"]:
        errors.append(f"{path}: must have at least {schema['minLength']} characters")
    if isinstance(value, int) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path}: must be at least {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path}: must be at most {schema['maximum']}")
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{path}: missing required property {key!r}")
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in properties:
                    errors.append(f"{path}: additional property {key!r}")
        elif isinstance(schema.get("additionalProperties"), dict):
            for key, child_value in value.items():
                if key not in properties:
                    errors.extend(validate(child_value, schema["additionalProperties"],
                                           f"{path}.{key}"))
        for key, child_schema in properties.items():
            if key in value:
                errors.extend(validate(value[key], child_schema, f"{path}.{key}"))
    if isinstance(value, list):
        if schema.get("uniqueItems") is True:
            serialized = [json.dumps(item, sort_keys=True, separators=(",", ":")) for item in value]
            if len(serialized) != len(set(serialized)):
                errors.append(f"{path}: items must be unique")
        item_schema = schema.get("items")
        if item_schema is not None:
            for index, item in enumerate(value):
                errors.extend(validate(item, item_schema, f"{path}[{index}]"))
    return errors


def require_valid(name: str, value: Any, schema: dict[str, Any]) -> None:
    errors = validate(value, schema)
    if errors:
        raise AssertionError(f"{name} failed JSON Schema validation: {'; '.join(errors)}")


def main() -> int:
    schema = load(SCHEMA_PATH)
    defaults = load(DEFAULTS_PATH)
    fixture = load(V7_FIXTURE_PATH)
    require_valid("shipped defaults", defaults, schema)
    require_valid("v7 runtime fixture", fixture, schema)

    hidden_dock = copy.deepcopy(defaults)
    hidden_dock["modules"]["dock"]["visibilityMode"] = "hidden"
    require_valid("hidden Dock runtime fixture", hidden_dock, schema)

    custom_notifications = copy.deepcopy(defaults)
    custom_notifications["modules"]["notifications"].update({
        "policyMode": "custom",
        "allowCriticalOnIsland": False,
        "keepCriticalUnread": False,
        "applicationOverrides": {
            "org.example.Mail": "follow",
            "org.example.Chat": "quiet",
            "org.example.Calendar": "normal",
            "org.example.Build": "critical",
            "org.example.Spam": "block",
        },
    })
    require_valid("custom notification policy fixture", custom_notifications, schema)

    schema_modes = set(schema["properties"]["modules"]["properties"]["dock"]
                       ["properties"]["visibilityMode"]["enum"])
    validator_source = VALIDATOR_PATH.read_text(encoding="utf-8")
    match = re.search(
        r'dock\.get\("visibilityMode"\) not in (\{[^\n]+\})', validator_source)
    if match is None:
        raise AssertionError("could not find the Dock visibility validator enum")
    validator_modes = set(ast.literal_eval(match.group(1)))
    if schema_modes != validator_modes:
        raise AssertionError(
            f"Dock visibility schema/validator mismatch: {schema_modes} != {validator_modes}")

    invalid_style = copy.deepcopy(defaults)
    invalid_style["modules"]["bar"]["style"] = "detached-ish"
    errors = validate(invalid_style, schema)
    if not any(error.startswith("$.modules.bar.style:") for error in errors):
        raise AssertionError("invalid bar style was accepted by the JSON Schema")
    invalid_policy = copy.deepcopy(defaults)
    invalid_policy["modules"]["notifications"]["policyMode"] = "unsafe"
    errors = validate(invalid_policy, schema)
    if not any(error.startswith("$.modules.notifications.policyMode:") for error in errors):
        raise AssertionError("invalid notification policy mode was accepted by the JSON Schema")
    invalid_override = copy.deepcopy(defaults)
    invalid_override["modules"]["notifications"]["applicationOverrides"] = {
        "org.example.Mail": "unsafe",
    }
    errors = validate(invalid_override, schema)
    if not any(error.startswith("$.modules.notifications.applicationOverrides.org.example.Mail:")
               for error in errors):
        raise AssertionError("invalid notification override was accepted by the JSON Schema")
    print("PASS settings v7 JSON Schema defaults, notification policy, hidden-Dock parity, fixture, and invalid-style rejection")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
