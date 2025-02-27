
from vsg.rules import single_space_between_token_pairs as Rule

from vsg.token import context_reference as token

lTokenPairs = []
lTokenPairs.append([token.keyword, token.library_name])
lTokenPairs.append([token.keyword, token.context_name])


class rule_002(Rule):
    '''
    This rule checks for a single space between the **context** keyword and the context selected name.

    **Violation**

    .. code-block:: vhdl

       context   c1;

    **Fix**

    .. code-block:: vhdl

       context c1;
    '''
    def __init__(self):
        Rule.__init__(self, 'context_ref', '002', lTokenPairs)
        self.solution = 'Reduce spaces between *context* keyword and selected_name.'
