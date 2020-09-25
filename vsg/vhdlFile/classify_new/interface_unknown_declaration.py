
from vsg.token import interface_unknown_declaration as token

from vsg.vhdlFile import utils

from vsg.vhdlFile.classify_new import expression
from vsg.vhdlFile.classify_new import identifier_list
from vsg.vhdlFile.classify_new import mode
from vsg.vhdlFile.classify_new import subtype_indication

'''
    This is a classification if the signal, constant, or variable keywords can not be found.
    This is not in the VHDL LRM.
    It is based off the interface_signal_declaration as it has the most keywords.

    interface_unknown_declaration ::=
        identifier_list : [ mode ] subtype_indication [ bus ] [ := *static*_expression ]
'''

def detect(iToken, lObjects):
    if utils.is_next_token_one_of(['type', 'file', 'function', 'procedure', 'impure', 'pure', 'package'], iToken, lObjects):
        return iToken
    else:
        return classify(iToken, lObjects)


def classify(iToken, lObjects):

    iCurrent = identifier_list.classify_until([':'], iToken, lObjects, token.identifier)

    iCurrent = utils.assign_next_token_required(':', token.colon, iCurrent, lObjects)

    iCurrent = mode.classify(iCurrent, lObjects)

    iCurrent = subtype_indication.classify_until([';', 'bus', ':='], iCurrent, lObjects)

    iCurrent = utils.assign_next_token_if('bus', token.bus_keyword, iCurrent, lObjects)

    if utils.is_next_token(':=', iCurrent, lObjects):
        iCurrent = utils.assign_next_token_required(':=', token.assignment, iCurrent, lObjects)

        iCurrent = expression.classify_until(';', iCurrent, lObjects)

    return iCurrent
