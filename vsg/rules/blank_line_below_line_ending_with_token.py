
from vsg import rule
from vsg import parser
from vsg import violation


class blank_line_below_line_ending_with_token(rule.Rule):
    '''
    Checks for a blank line below a line ending with a given token

    Parameters
    ----------

    name : string
       The group the rule belongs to.

    identifier : string
       unique identifier.  Usually in the form of 00N.

    token: token object type list
       token object that a blank line below should appear
    '''

    def __init__(self, name, identifier, lTokens, lAllowTokens=[]):
        rule.Rule.__init__(self, name=name, identifier=identifier)
        self.solution = 'Insert blank line below'
        self.phase = 3
        self.lTokens = lTokens
        self.lHierarchyLimits = None
        self.lAllowTokens = lAllowTokens
        self.style = 'require_blank_line'
        self.configuration.append('style')

    def _get_tokens_of_interest(self, oFile):
        if self.style == 'require_blank_line':
            if self.lHierarchyLimits is None:
                return oFile.get_line_below_line_ending_with_token(self.lTokens)
            else:
                return oFile.get_line_below_line_ending_with_token_with_hierarchy(self.lTokens, self.lHierarchyLimits)
        elif self.style == 'no_blank_line':
            return oFile.get_blank_lines_below_line_ending_with_token(self.lTokens, self.lHierarchyLimits)

    def _analyze(self, lToi):
        if self.style == 'require_blank_line':
            _analyze_require_blank_line(self, lToi, self.lAllowTokens)
        elif self.style == 'no_blank_line':
            _analyze_no_blank_line(self, lToi, self.lAllowTokens)

    def _fix_violation(self, oViolation):
        lTokens = oViolation.get_tokens()
        dAction = oViolation.get_action()
        if dAction['action'] == 'Insert':
            lTokens.insert(0, parser.carriage_return())
            lTokens.insert(0, parser.blank_line())
            oViolation.set_tokens(lTokens)
        elif dAction['action'] == 'Remove':
            oViolation.set_tokens([])


def _analyze_require_blank_line(self, lToi, lAllowTokens):
        for oToi in lToi:
            lTokens = oToi.get_tokens()
            if _is_allowed_token(lAllowTokens, lTokens):
                continue
            if len(lTokens) == 1:
                if isinstance(lTokens[0], parser.blank_line):
                    continue
            oViolation = violation.New(oToi.get_line_number() - 1, oToi, self.solution)
            dAction = {}
            dAction['action'] = 'Insert'
            oViolation.set_action(dAction)
            self.add_violation(oViolation)


def _analyze_no_blank_line(self, lToi, lAllowTokens):
        for oToi in lToi:
            oViolation = violation.New(oToi.get_line_number() + 1, oToi, self.solution)
            dAction = {}
            dAction['action'] = 'Remove'
            oViolation.set_action(dAction)
            self.add_violation(oViolation)


def _is_allowed_token(lAllowTokens, lTokens):
    bSkip = False
    for oAllowToken in lAllowTokens:
        for oToken in lTokens:
            if isinstance(oToken, oAllowToken):
                bSkip = True
                break
        if bSkip:
           break
    if bSkip:
        return True
    return False
