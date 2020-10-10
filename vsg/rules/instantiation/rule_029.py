
from vsg.rules import align_tokens_in_region_between_tokens_skipping_lines_starting_with_tokens

from vsg import parser
from vsg import token

lAlign = []
lAlign.append(parser.comment)

lSkip = []
lSkip.append(parser.comment)

class rule_029(align_tokens_in_region_between_tokens_skipping_lines_starting_with_tokens):
    '''
    Ensures the alignment of inline comments in an instantiation.
    '''

    def __init__(self):
        align_tokens_in_region_between_tokens_skipping_lines_starting_with_tokens.__init__(self, 'instantiation', '029', lAlign, token.component_instantiation_statement.instantiation_label, token.component_instantiation_statement.semicolon, lSkip)
        self.solution = 'Align comment.'
        self.subphase = 3
