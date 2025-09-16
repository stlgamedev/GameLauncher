import re
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

def get_version_from_projectxml(projectxml_path):
    tree = ET.parse(projectxml_path)
    root = tree.getroot()
    version = root.attrib.get('version')
    if not version:
        # Try to find <version> tag
        version_tag = root.find('version')
        if version_tag is not None:
            version = version_tag.text.strip()
    if not version:
        raise Exception('Could not find version in Project.xml')
    return version

def update_iss_version(iss_path, version):
    lines = Path(iss_path).read_text(encoding='utf-8').splitlines()
    new_lines = []
    found = False
    for line in lines:
        if line.strip().startswith('#define VERSION'):
            new_lines.append(f'#define VERSION "{version}"')
            found = True
        else:
            new_lines.append(line)
    if not found:
        raise Exception('No #define VERSION line found in .iss file')
    Path(iss_path).write_text('\n'.join(new_lines) + '\n', encoding='utf-8')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: python update_iss_version.py <Project.xml> <STLGameLauncher.iss>')
        sys.exit(1)
    projectxml = sys.argv[1]
    issfile = sys.argv[2]
    version = get_version_from_projectxml(projectxml)
    update_iss_version(issfile, version)
    print(f'Updated {issfile} to version {version}')
