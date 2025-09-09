import re
import os
import sys

# Path to Project.xml (assume script is run from any location)
project_xml = os.path.abspath(os.path.join(os.path.dirname(__file__), '../Project.xml'))
# Path to version.rc.in template (in bin)
rc_template = os.path.abspath(os.path.join(os.path.dirname(__file__), '../export/windows/bin/version.rc.in'))
# Output rc file (in bin)
rc_out = os.path.abspath(os.path.join(os.path.dirname(__file__), '../export/windows/bin/version.rc'))

def get_version_from_project_xml(xml_path):
    with open(xml_path, encoding='utf-8') as f:
        content = f.read()
    m = re.search(r'<app[^>]*version="([0-9]+)\.([0-9]+)\.([0-9]+)"', content)
    if not m:
        raise Exception('Version not found in Project.xml')
    return m.group(1), m.group(2), m.group(3)

def generate_version_rc():
    major, minor, patch = get_version_from_project_xml(project_xml)
    with open(rc_template, encoding='utf-8') as f:
        template = f.read()
    rc = template.replace('@MAJOR@', major).replace('@MINOR@', minor).replace('@PATCH@', patch)
    with open(rc_out, 'w', encoding='utf-8') as f:
        f.write(rc)
    print(f'Generated {rc_out} with version {major}.{minor}.{patch}')

if __name__ == '__main__':
    generate_version_rc()
