from common_lex import make_lexer
(lexer, tokens) = make_lexer(literals=':')

##--------------------------------------------------------------------------------------------------------------------##

start = 'content'

cpuid = {}

def p_content(p):
	'''content : ID ":" args'''
	if p[1] in cpuid and cpuid[p[1]]!=p[3]:
		print('WARNING: incoherent cpuid', p[3], cpuid[p[1]])
	cpuid[p[1]] = p[3]

def p_args_more(p):
	'''args : args ID'''
	p[0] = p[1]
	p[0].append(p[2])

def p_args_none(p):
	'''args : '''
	p[0] = []

def p_error(p):
	if p:
		print('cpuid', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='cpuid_table')

def parse(line):
	parser.parse(line, lexer=lexer)