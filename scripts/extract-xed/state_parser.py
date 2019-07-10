from ply.lex import lex, TOKEN

operators = {
	'=': 'EQ',
	'!=': 'NE'
}

keywords = {
	'otherwise': 'OTHERWISE',
}

tokens = ['ID', 'HEX', 'BIN', 'NO'] + list(keywords.values()) + list(operators.values())
operator_chars = r'!='
literals = '][()'
t_ignore_COMMENT = r'\#.*'
t_ignore = '\t \n\r'

def t_BIN(t):
	r'0[bB][01_]+'
	t.value = (int(t.value, 2), len(t.value))
	return t

def t_HEX(t):
	r'0[xX][A-Fa-f0-9_]+'
	t.value = (int(t.value, 16), len(t.value))
	return t

def t_NO(t):
	r'[0-9_]+(?![A-Za-z20-9_])'
	t.value = int(t.value)
	return t

@TOKEN(r'[' + operator_chars + ']+')
def t_OPERATOR(t):
	t.type = operators.get(t.value, None)
	return t

id_chars = r'[^' + literals + operator_chars + r'\s#]'

@TOKEN(id_chars + '+')
def t_ID(t):
	t.type = keywords.get(t.value, 'ID')
	return t

def t_error(t):
	pass

lexer = lex()

##--------------------------------------------------------------------------------------------------------------------##

start = 'content'

state = {}

def p_content(p):
	'''content : ID new_bits''' 
	if p[1] in state and state[p[1]]!=p[2]:
		print('WARNING: incoherent state', p[2], state[p[1]])
	state[p[1]] = p[2]

def p_new_bits_item(p):
	'''new_bits : parse_opcode_spec new_bits'''
	p[0] = p[1] + p[2]

def p_new_bits_state(p):
	'''new_bits : ID new_bits'''
	p[0] = list(p[1].replace('_', '')) + p[2]
	# TODO

def p_new_bits_otherwise(p):
	'''new_bits : OTHERWISE'''
	p[0] = [p[1]]
	# pass

def p_new_bits_none(p):
	'''new_bits : '''
	p[0] = []

def p_parse_opcode_spec_bin(p):
	'''parse_opcode_spec : BIN'''
	p[0] = list(make_bits(p[1][0], p[1][1]))

def p_parse_opcode_spec_hex(p):
	'''parse_opcode_spec : HEX'''
	p[0] = list(make_bits(p[1][0], p[1][1]))

def p_parse_opcode_spec_binding(p):
	'''parse_opcode_spec : ID "[" bit_pattern "]"'''
	p[0] = [(p[1], x) for x in p[3]]
	# validate_field_width

def p_parse_opcode_spec_nt(p):
	'''parse_opcode_spec : ID "(" ")"'''
	p[0] = [p[1]]

def p_parse_opcode_spec_restriction(p):
	'''parse_opcode_spec : ID EQ number
	                     | ID NE number
	                     | ID EQ ID'''
	p[0] = [tuple(p[1:])]

def p_bit_pattern_raw(p):
	'''bit_pattern : ID "/" number
	               | ID'''
	p[0] = p[1] * (p[3] if len(p)==4 else 1)

def p_bit_pattern_prefix(p):
	'''bit_pattern : BIN'''
	p[0] = make_bits(p[1][0], p[1][1])

def p_number_std(p):
	'''number : HEX
	          | BIN'''
	p[0] = p[1][0]

def p_number_bits(p):
	'''number : NO'''
	p[0] = p[1]

def p_error(p):
	if p:
		print('state', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='state_table')

def parse(line):
	parser.parse(line, lexer=lexer)