
from vsg.rules import single_space_after_token as Rule

from vsg.token import iteration_scheme as token

lTokens = []
lTokens.append(token.for_keyword)


class rule_101(Rule):
    '''
    This rule checks that a single space exists after the **for** keyword.

    **Violation**

    .. code-block:: vhdl

       for      x in (31 downto 0) loop

    **Fix**

    .. code-block:: vhdl

       for x in (31 downto 0) loop
    '''
    def __init__(self):
        Rule.__init__(self, 'iteration_scheme', '101', lTokens)
        self.solution = 'Ensure a single space after for keyword.'
