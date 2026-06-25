import re, os, glob

# Find app.js wherever it landed in gst-web
candidates = glob.glob('/opt/gst-web/**/app.js', recursive=True)
if not candidates:
    raise FileNotFoundError('Could not find app.js under /opt/gst-web')

path = candidates[0]
print(f'Patching {path}')

with open(path, 'r') as f:
    content = f.read()

content = re.sub(
    r'window\.location\.pathname\.endsWith.*?"webrtc"',
    '"selkies"',
    content,
    flags=re.DOTALL
)

with open(path, 'w') as f:
    f.write(content)

print('Patched appName -> selkies')