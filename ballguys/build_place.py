"""Builds BallGuysMerge.rbxlx (open in Roblox Studio) from the .lua files here."""
import itertools, pathlib
here = pathlib.Path(__file__).parent
ref = itertools.count(1)

def item(cls, name, children="", source=None):
    src = f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>' if source is not None else ""
    return (f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties>'
            f'<string name="Name">{name}</string>{src}</Properties>{children}</Item>')

read = lambda f: (here / f).read_text()
modules = "".join(item("ModuleScript", n, source=read(f"{n}.lua")) for n in ["Config", "MergeGame", "SimpleSim"])
xml = ('<roblox version="4">'
       + item("Workspace", "Workspace")
       + item("ReplicatedStorage", "ReplicatedStorage", item("Folder", "BallGuys", modules))
       + item("StarterPlayer", "StarterPlayer",
              item("StarterPlayerScripts", "StarterPlayerScripts",
                   item("LocalScript", "MergeClient", source=read("Client.client.lua"))))
       + '</roblox>')
(here / "BallGuysMerge.rbxlx").write_text(xml)
print("wrote BallGuysMerge.rbxlx")
