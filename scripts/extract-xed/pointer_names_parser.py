from common_lex import make_lexer
(lexer, tokens) = make_lexer()

##--------------------------------------------------------------------------------------------------------------------##

start = 'content'

pointer_names = []

def p_content(p):
	'''content : NUMBER ID ID'''
	pointer_names.append(tuple(p[1:]))

def p_error(p):
	if p:
		print('pointer-names', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='pointer_names_table')

def parse(line):
	parser.parse(line, lexer=lexer)