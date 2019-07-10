from common_lex import make_lexer
(lexer, tokens) = make_lexer({
	'EI': 'EI',
	'EO': 'EO',
	'DI': 'DI',
	'DO': 'DO',
	'DS': 'DS',
	'SCALAR': 'SCALAR',
	'NOPRINT': 'NOPRINT',
	'PRINT': 'PRINT',
	'INTERNAL': 'INTERNAL',
	'PUBLIC': 'PUBLIC',
	'enum': 'ENUM',
	'xed_reg_enum_t': 'XRET',
	'xed_iclass_enum_t': 'XIET'})

##--------------------------------------------------------------------------------------------------------------------##

start = 'content'

fields = {}

def p_content(p):
	'''content : ID SCALAR type NUMBER ID xp ip dio eio'''
	fields[p[1]] = tuple(p[3:])

def p_type(p):
	'''type : ID
	        | XRET
	        | XIET
	        | ENUM'''
	# operand_storage.operand_storage_t._read_storage_fields
	p[0] = p[1]

def p_xp(p):
	'''xp : PRINT
	      | NOPRINT'''
	p[0] = p[1]=='PRINT'

def p_ip(p):
	'''ip : INTERNAL
	      | PUBLIC'''
	p[0] = p[1]=='PUBLIC'

def p_dio(p):
	'''dio : DI
	       | DO
           | DS'''
	p[0] = p[1]

def p_eio(p):
	'''eio : EI
	       | EO'''
	p[0] = p[1]=='EI'

def p_error(p):
	if p:
		print('fields', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='fields_table')

def parse(line):
	parser.parse(line, lexer=lexer)