"""Windows-side syntax/configuration checks; not an iOS build or runtime test."""
from pathlib import Path
import csv
import io
import yaml
from tree_sitter import Language, Parser
import tree_sitter_swift

root = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))
files = list(root.glob("FollowUp/*.swift")) + list(root.glob("FollowUpTests/*.swift"))
errors = []
for path in files:
    tree = parser.parse(path.read_bytes())
    stack = [tree.root_node]
    while stack:
        node = stack.pop()
        if node.type == "ERROR" or node.is_missing:
            errors.append(f"{path.name}:{node.start_point.row + 1}: {node.type}: {path.read_bytes()[node.start_byte:node.end_byte]!r}")
        stack.extend(node.children)
assert not errors, "\n".join(errors)

config = yaml.safe_load((root / "project.yml").read_text(encoding="utf-8"))
assert config["targets"]["FollowUp"]["platform"] == "iOS"
assert "FollowUpTests" in config["schemes"]["FollowUp"]["test"]["targets"]
for target in config["targets"].values():
    for source in target["sources"]:
        assert (root / source).is_dir(), source

template = root / "templates" / "问答话术模板.csv"
header = ["类型", "问题", "相似问法", "回答", "产品", "标签", "来源"]
rows = list(csv.reader(io.StringIO(template.read_text(encoding="utf-8-sig"), newline="")))
assert rows[0] == header
assert all(len(row) == 7 and row[0] in ("问答", "话术") and row[1] and row[3] for row in rows[1:])
print(f"PASS: {len(files)} Swift files parsed; XcodeGen config and CSV template validated.")
print("iOS type checking, XCTest and device behavior require Xcode on macOS.")
