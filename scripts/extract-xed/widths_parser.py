tokens = ['BITS', 'NUMBER', 'ID']

def t_BITS(t):
	r'[0-9]+bits'
	t.value = int(t.value[:-4])
	return t

def t_NUMBER(t):
	r'(0[xX][0-9A-Fa-f_]+)|(0[bB][01_]+)|(0[oO][0-8]+)|([0-9]+)'
	t.value = 8*int(t.value, 0)
	return t

from common_lex import t_ignore_COMMENT, make_identifier_token, t_ignore, t_error

t_ID = make_identifier_token()

from ply.lex import lex

lexer = lex()

##--------------------------------------------------------------------------------------------------------------------##

start = 'content'

widths = {}

def p_content(p):
	'''content : ID ID bn bn bn
	           | ID ID bn'''
	p[1] = p[1].upper()
	w = tuple([p[2], 0 if len(p)==6 else p[3]] + (p[3:4] * 3 if len(p)==4 else p[3:6]))
	if p[1] in widths and widths[p[1]]!=w:
		print('WARNING: incoherent width', w, widths[p[1]])
	widths[p[1]] = w

def p_bn(p):
	'''bn : BITS
	      | NUMBER'''
	p[0] = p[1]

def p_error(p):
	if p:
		print('widths', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='widths_table')

def parse(line):
	parser.parse(line, lexer=lexer)