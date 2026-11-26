#!/usr/bin/env python3
"""Bouwt Roblomberman.rbxlx uit de scripts in src/ (geen Rojo nodig)."""
import pathlib, itertools
root = pathlib.Path(__file__).parent
ref = itertools.count(1)

def script(cls, name, path):
    src = (root / path).read_text()
    assert "]]>" not in src
    return f'''<Item class="{cls}" referent="RBX{next(ref)}"><Properties>
<string name="Name">{name}</string>
<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString>
</Properties></Item>'''

def folder(cls, name, children=""):
    return f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties><string name="Name">{name}</string></Properties>{children}</Item>'

xml = f'''<roblox version="4">
{folder("Workspace", "Workspace")}
{folder("Lighting", "Lighting")}
{folder("Players", "Players")}
{folder("ReplicatedStorage", "ReplicatedStorage", script("ModuleScript", "BombConfig", "src/ReplicatedStorage/BombConfig.lua"))}
{folder("ServerScriptService", "ServerScriptService", script("Script", "BombermanServer", "src/ServerScriptService/BombermanServer.server.lua"))}
{folder("StarterPlayer", "StarterPlayer", folder("StarterPlayerScripts", "StarterPlayerScripts", script("LocalScript", "BombermanClient", "src/StarterPlayerScripts/BombermanClient.client.lua")))}
</roblox>'''
(root / "Roblomberman.rbxlx").write_text(xml)
print("Roblomberman.rbxlx gebouwd")
