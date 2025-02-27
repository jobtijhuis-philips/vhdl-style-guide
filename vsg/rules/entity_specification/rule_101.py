
from vsg import token

from vsg.rules import whitespace_before_token

lTokens = []
lTokens.append(token.entity_specification.colon)


class rule_101(whitespace_before_token):
    '''
    This rule checks for at least a single space before the colon.

    **Violation**

    .. code-block:: vhdl

       attribute coordinate of comp_1: component is (0.0, 17.5);

       attribute coordinate of comp_1     : component is (0.0, 17.5);

    **Fix**

    .. code-block:: vhdl

       attribute coordinate of comp_1 : component is (0.0, 17.5);

       attribute coordinate of comp_1     : component is (0.0, 17.5);
    '''
    def __init__(self):
        whitespace_before_token.__init__(self, 'entity_specification', '101', lTokens)
