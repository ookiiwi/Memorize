from langcodes import Language
import os
import subprocess

class Target:
    def __init__(self, src, dst, xmlFilename, sub=None):
        self.src = src
        self.dst = dst
        self.sub = sub
        self.xmlFilename = xmlFilename

targets = [
    Target('jpn', ['eng', 'ger', 'fre', 'rus', 'spa', 'hun', 'slv', 'dut', 'swe'], 'JMdict'),
    Target('jpn', ['en', 'fr', 'es', 'pt'], 'kanjidic2', 'kanji'),
]

realpath = os.path.dirname(os.path.realpath(__file__))

for target in targets:
    for dst in target.dst:
        dst3 = Language.get(dst).to_alpha3()
        filename = f"{realpath}/tei/{target.src}-{dst3}{('-' + target.sub if target.sub else '')}.tei"
        draft = f'{realpath}/tei/draft.tei'

        if (os.path.isfile(filename)):
            continue

        tranfo = f"xsltproc --stringparam targetlang {dst} -o {draft} -novalid {realpath}/xsl/{target.xmlFilename}2tei.xsl {realpath}/xml/{target.xmlFilename}.xml"
        format = f"\nxmllint --format {draft} > {filename}"

        subprocess.run(['bash', '-c', f"{tranfo}; {format}; rm {draft}"], stdout=subprocess.PIPE, text=True)

