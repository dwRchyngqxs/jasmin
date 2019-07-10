from common_lex import make_lexer
(lexer, tokens) = make_lexer({
	'nt': 'NT',
	'reg': 'REG',
	'imm_const': 'IMMC'})

##--------------------------------------------------------------------------------------------------------------------##

start = 'content'

extra_widths_reg = {}
extra_widths_nt = {}
extra_widths_imm_const = {}

def p_content_nt(p):
	'''content : NT ID ID'''
	extra_widths_nt[p[2]] = p[3]

def p_content_reg(p):
	'''content : REG ID ID'''
	extra_widths_reg[p[2]] = p[3]
	

def p_content_immc(p):
	'''content : IMMC ID ID'''
	extra_widths_imm_const[p[2]] = p[3]

def p_error(p):
	if p:
		print('extra-widths', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='extra_widths_table')

def parse(line):
	parser.parse(line, lexer=lexer)