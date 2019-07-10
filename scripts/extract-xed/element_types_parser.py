from common_lex import make_lexer
(lexer, tokens) = make_lexer()

##--------------------------------------------------------------------------------------------------------------------##

start = 'content'

element_types = {}

def p_content(p):
	'''content : ID ID NUMBER'''
	element_types[p[1]] = tuple(p[2:])

def p_error(p):
	if p:
		print('element-types', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='element_types_table')

def parse(line):
	parser.parse(line, lexer=lexer)