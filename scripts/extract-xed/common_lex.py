from ply.lex import TOKEN, lex

t_ignore_COMMENT = r'\#.*'
t_ignore = '\t \n\r'

def t_NUMBER(t):
	r'((0[xX][0-9A-Fa-f_]+)|(0[bB][01_]+)|(0[oO][0-8]+)|([0-9]+))(?![A-Za-z20-9_])'
	t.value = int(t.value, 0)
	return t

def make_identifier_token(reserved = {}, literals = ''):
	@TOKEN(r'[^\s#' + literals + r']+')
	def identifier_token(t):
		nonlocal reserved
		t.type = reserved.get(t.value, 'ID')
		return t
	return identifier_token

def t_error(t):
	print('lexer error', t)
	return

def make_lexer(reserved = {}, literals = ''):
	tokens = ['NUMBER', 'ID'] + list(reserved.values())
	t_ID = make_identifier_token(reserved, literals)
	return (lex(), tokens)