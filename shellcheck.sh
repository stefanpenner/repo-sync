#!/usr/bin/env bash
find src -type f -name "*.sh" | xargs shellcheck
