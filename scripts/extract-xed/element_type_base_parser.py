from ply.lex import lex

reserved = {
	'cplusplus': 'CPP',
	'namespace': 'NS',
	'hfn': 'HFN',
	'cfn': 'CFN',
	'density': 'DEN',
	'prefix': 'PRE',
	'typename': 'TN',
	'stream_ifdef': 'SI',
	'proto_prefix': 'PP',
	'extra_header': 'EH'
}

tokens = ['ID'] + list(reserved.values())

comment = None
def t_ignore_DOXCOM(t):
	r'//[/!]<[^\#]*'
	global comment
	comment = t.value.strip()

from common_lex import t_ignore_COMMENT, t_ignore, make_identifier_token, t_error

t_ID = make_identifier_token(reserved, '/')

lexer = lex()

##--------------------------------------------------------------------------------------------------------------------##

start = 'content'

element_type_base = []

def p_content(p):
	'''content : ID ID
	           | ID'''
	global comment
	element_type_base.append((p[1], p[2] if len(p)==3 else None, comment))
	comment = None

def p_cpp(p):
	'''content : CPP'''
	pass

def p_ns(p):
	'''content : NS ID'''
	pass

def p_hfn(p):
	'''content : HFN ID'''
	pass

def p_cfn(p):
	'''content : CFN ID'''
	pass

def p_den(p):
	'''content : DEN ID'''
	pass

def p_pre(p):
	'''content : PRE ID'''
	pass

def p_tn(p):
	'''content : TN ID'''
	pass

def p_si(p):
	'''content : SI ID'''
	pass

def p_pp(p):
	'''content : PP ID'''
	pass

def p_eh(p):
	'''content : EH ID'''
	pass

def p_error(p):
	if p:
		print('element-type-base', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='element_type_base_table')

def parse(line):
	parser.parse(line, lexer=lexer)