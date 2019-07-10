from common_lex import make_lexer
(lexer, tokens) = make_lexer(literals='/')

##--------------------------------------------------------------------------------------------------------------------##

start = 'content'

registers = {}

def p_content(p):
	'''content : ID ID width merp NUMBER hreg ID
	           | ID ID width merp NUMBER hreg
	           | ID ID width merp NUMBER
	           | ID ID width merp
	           | ID ID width'''
	p[1] = p[1].upper()
	p[2] = p[2].upper()
	if p[1] not in registers or registers[p[1]][0][2] < p[3]:
		registers[p[1]] = []
	registers[p[1]].append(tuple(p[1:4] + [(p[1], p[1]) if len(p) < 5 else p[4],
		0 if len(p) < 6 else p[5], len(p) > 7 and p[6], p[1] if len(p) < 8 else p[7].upper()]))

def p_width(p):
	'''width : NUMBER
	         | NUMBER "/" NUMBER
			 | ID'''
	if type(p[1])=='str':
		if p[1]=='NA':
			p[1] = 0
		else:
			raise SyntaxError
	p[0] = (p[1], p[1] if len(p)==2 else p[3])

def p_merp(p):
	'''merp : ID "/" ID
	        | ID'''
	p[1] = p[1].upper()
	p[0] = (p[1], p[1] if len(p)==2 else p[3].upper())

def p_hreg(p):
	'''hreg : ID'''
	if p[1]=='h':
		p[0] = True
	if p[1]=='-':
		p[0] = False
	if not (p[0] or p[0] is False):
		raise SyntaxError

def p_error(p):
	if p:
		print('registers', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='registers_table')

def parse(line):
	parser.parse(line, lexer=lexer)