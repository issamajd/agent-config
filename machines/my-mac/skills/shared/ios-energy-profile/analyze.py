"""Summarises a trace from record.sh.

usage: python3 -I analyze.py <trace> [process ...]

Prints, per 10 s bucket, the top five processes by CPU (100% = one core) and
the display's surface swaps per second (0 = nothing on screen is changing),
then each named process's CPU per bucket, then the thermal state intervals.
"""
import collections
import subprocess
import sys
import xml.etree.ElementTree as ET

BUCKET = 10e9  # ns


def table(trace, schema):
    xpath = f'/trace-toc/run[@number="1"]/data/table[@schema="{schema}"]'
    out = subprocess.run(
        ['xcrun', 'xctrace', 'export', '--input', trace, '--xpath', xpath],
        capture_output=True, check=True,
    ).stdout
    return ET.fromstring(out) if out.strip() else None


def rows(root):
    """Rows as {mnemonic: (fmt, text)}, with xctrace's id/ref sharing resolved."""
    if root is None or root.find('.//schema') is None:
        return
    cols = [c.findtext('mnemonic') for c in root.find('.//schema').findall('col')]
    ids = {}

    def resolve(el):
        if 'ref' in el.attrib:
            return ids[el.attrib['ref']]
        if 'id' in el.attrib:
            ids[el.attrib['id']] = el
        for child in el:
            resolve(child)
        return el

    for r in root.iter('row'):
        yield {c: (e.attrib.get('fmt'), e.text) for c, e in zip(cols, map(resolve, r))}


def main(trace, names):
    cumulative = collections.defaultdict(dict)  # process -> {t: cpu ns so far}
    for r in rows(table(trace, 'activity-monitor-process-live')):
        name = r['process'][0].rsplit(' (', 1)[0]
        cumulative[name][int(r['start'][1])] = int(r['cpu-total'][1] or 0)
    cpu = collections.defaultdict(lambda: collections.defaultdict(float))
    for name, series in cumulative.items():
        times = sorted(series)
        for a, b in zip(times, times[1:]):
            cpu[int(b // BUCKET)][name] += max(0, series[b] - series[a])
    swaps = collections.defaultdict(list)
    for r in rows(table(trace, 'displayed-surfaces-per-second')):
        swaps[int(int(r['start'][1]) // BUCKET)].append(int(r['count'][1]))

    print('== Top processes (CPU % of one core per 10 s)')
    for b in sorted(cpu):
        s = swaps.get(b, [])
        top = sorted(cpu[b].items(), key=lambda kv: -kv[1])[:5]
        print(f'{b * 10:4d}s swaps/s {sum(s) / len(s) if s else 0:4.0f}  '
              + '  '.join(f'{k[:16]}={v / BUCKET * 100:.0f}%' for k, v in top))
    if names:
        print('\n== Named processes')
        for b in sorted(cpu):
            print(f'{b * 10:4d}s ' + '  '.join(
                f'{n}={cpu[b].get(n, 0) / BUCKET * 100:5.1f}%' for n in names))
    print('\n== Thermal state')
    for r in rows(table(trace, 'device-thermal-state-intervals')):
        print(f"{r['start'][0]}  for {r['duration'][0]:>10}  {r['thermal-state'][0]}")


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2:])
