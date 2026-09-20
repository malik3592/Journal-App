# -*- mode: python ; coding: utf-8 -*-
a = Analysis(
    ['../app/main.py'],
    pathex=['..'],
    binaries=[],
    datas=[],
    hiddenimports=['MetaTrader5'],
    hookspath=[],
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='journal-mt5-worker',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
)
