from common_lex import make_lexer
(lexer, tokens) = make_lexer({
	'clear': 'CLEAR',
	'define': 'DEFINE',
	'remove-source': 'REMSRC',
	'add-source': 'ADDSRC',
	'remplace-source': 'REPLSRC',
	'remove': 'REM',
	'add': 'ADD'}, ':')

##--------------------------------------------------------------------------------------------------------------------##

import os
import re

start = 'content'

__path = '.'
configs = {}
path_expand = re.compile(r'%[(].+?[)]')

def p_content_add(p):
	'''content : ADD ":" ID ":" ID ":" NUMBER
	           | ADD ":" ID ":" ID
	           | ID ":" ID ":" NUMBER
	           | ID ":" ID'''
	first = 1
	if p[1]=='add':
		first+= 2
	if path_expand.search(p[first + 2]):
		p[first + 2] = p[first + 2] % {'xed_dir': '.'}
	else:
		p[first + 2] = os.path.join(__path, p[first + 2])
	# ignore priority
	if os.path.exists(p[first + 2]):
		if p[first] not in configs:
			configs[p[first]] = []
		configs[p[first]].append(p[first + 2])
	else:
		print('file not found:', p[first + 2])

def p_content_clear(p):
	'''content : CLEAR ":" ID'''
	pass

def p_content_define(p):
	'''content : DEFINE ":" ID'''
	pass

def p_content_remove_source(p):
	'''content : REMSRC ":" ID ":" ID'''
	pass

def p_content_add_source(p):
	'''content : ADDSRC ":" ID ":" ID ":" NUMBER
	           | ADDSRC ":" ID ":" ID'''
	pass

def p_content_replace_source(p):
	'''content : REPLSRC ":" ID ":" ID ":" ID ":" NUMBER
	           | REPLSRC ":" ID ":" ID ":" ID'''
	pass

def p_content_remove(p):
	'''content : REM ":" ID ":" ID'''
	pass

def p_error(p):
	if p:
		print('configs', p, p.lexer.lexdata)

from ply.yacc import yacc

parser = yacc(tabmodule='configs_table')

def parse(line, path):
	global __path
	__path = path
	parser.parse(line, lexer=lexer)