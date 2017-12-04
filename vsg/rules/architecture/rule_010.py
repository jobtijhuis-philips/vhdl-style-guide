
from vsg.rules.architecture import architecture_rule
from vsg import utilities

import re


class rule_010(architecture_rule):
    '''
    Architecture rule 010 checks for "architecture" in the "end architecture statement.
    '''

    def __init__(self):
        architecture_rule.__init__(self)
        self.identifier = '010'
        self.solution = 'Add "architecture" keyword after "end" keyword.'
        self.phase = 1

    def analyze(self, oFile):
        for iLineNumber, oLine in enumerate(oFile.lines):
            if oLine.isEndArchitecture:
                if not re.match('^\s*end\s+architecture', oLine.line, re.IGNORECASE):
                    self.add_violation(iLineNumber)

    def _fix_violations(self, oFile):
        for iLineNumber in self.violations:
            oLine = oFile.lines[iLineNumber]
            oLine.update_line(re.sub(r'^(\s*end)', r'\1 architecture', oLine.line, flags=re.IGNORECASE))
