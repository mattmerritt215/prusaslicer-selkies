import re
with open('/opt/gst-web/src/app.js', 'r') as f:
    content = f.read()
content = re.sub(
    r'window\.location\.pathname\.endsWith.*?"webrtc"',
    '"selkies"',
    content,
    flags=re.DOTALL
)
with open('/opt/gst-web/src/app.js', 'w') as f:
    f.write(content)
print('Patched appName -> selkies')