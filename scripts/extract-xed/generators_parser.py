from ply.lex import lex, TOKEN

states = (
	('cond', 'inclusive'),
	('arg', 'inclusive'),
	('eat', 'exclusive')
)

watch_a = False
watch_access = False
watch_rsf = False
watch_flag = False
watch_action = False

state = {}
widths = {}

a_s = {
	'AGEN': 'AGEN',
	'RELBR': 'RELBR',
	'PTR': 'PTR',
	'XED_RESET': 'RESET',
	'MEM0': 'MEMX',
	'MEM1': 'MEMX',
	'IMM0': 'IMMX',
	'IMM1': 'IMMX',
	'IMM2': 'IMMX',
	'IMM3': 'IMMX'
}


accesses = {
	'r': 'R',
	'w': 'W',
	'rw': 'RW',
	'crw': 'CRW',
	'rcw': 'RCW'
}


args = {
	'IMPL': 'IMPL',
	'SUPP': 'SUPP',
	'EXPL': 'EXPL',
	'ECOND': 'ECOND',
	'TXT': 'TXT'
}
xtypes = {}


rsfs = {
	'PATTERN': 'PAT',
	'OPERANDS': 'OPNDS',
	'IFORM': 'IFORM',
	'ICLASS': 'ICLS',
	'CATEGORY': 'CAT',
	'CPL': 'CPL',
	'EXTENSION': 'EXT',
	'ISA_SET': 'ISA',
	'ATTRIBUTES': 'ATTR',
	'VERSION': 'VER',
	'FLAGS': 'FLAGS',
	'UCODE': 'UC',
	'COMMENT': 'COM',
	'EXCEPTIONS': 'EXC',
	'DISASM': 'DISASM',
	'DISASM_INTEL': 'DISASMI',
	'DISASM_ATTSV': 'DISASMSV',
	'UNAME': 'UNAME'
}


flags = {
	'MAY': 'FLAGSPEC',
	'MUST': 'FLAGSPEC',
	'READONLY': 'FLAGSPEC',
	'REP': 'FLAGQUAL',
	'NOREP': 'FLAGQUAL',
	'IMMx': 'FLAGQUAL',
	'IMM0': 'FLAGQUAL',
	'IMM1': 'FLAGQUAL'
}


actions = {
	'mod': 'MOD',
	'tst': 'TST',
	'u': 'U',
	'0': 'ZERO',
	'1': 'ONE',
	'ah': 'AH',
	'pop': 'POP'
}


keywords = {
	'UDELETE': 'UDEL',
	'DELETE': 'DEL',
	'otherwise': 'OTHERWISE',
	# TODO field_check code_gen_instruction
}

operators = {
	'::': 'NTSP',
	':': 'COLON',
	'=': 'EQ',
	'!=': 'NE'
}

tokens = ['INSID', 'ID', 'HEX', 'BIN', 'NO', 'NEWLINE', 'XTYPE', 'MULTIREG', 'REG', 'ERR', 'ENUM', 'EATER'] + \
	list(set(a_s.values())) + list(accesses.values()) + list(args.values()) + list(rsfs.values()) + \
	list(set(flags.values())) + list(actions.values()) + list(keywords.values()) + list(operators.values())
literals = '][|/{}(),-'
operator_chars = r':!='
t_ignore_CONTINUATION = r'\\(?s:.)*'
t_ANY_ignore = '\t '
t_NEWLINE = r'(\#.*)|\n|\r'

def t_BIN(t):
	r'0[bB][01_]+'
	t.value = (int(t.value, 2), len(t.value))
	return t

def t_HEX(t):
	r'0[xX][A-Fa-f0-9_]+'
	t.value = (int(t.value, 16), len(t.value))
	return t

@TOKEN(r'[' + operator_chars + ']+')
def t_OPERATOR(t):
	t.type = operators.get(t.value, None)
	return t

t_eat_EATER = r'[^\#\n]*(?=(?s:.))'

id_chars = r'[^' + literals[:-1] + operator_chars + r'\s\\#-]'

@TOKEN(r'[0-9_]+(?!' + id_chars + ')')
def t_NO(t):
	if watch_action:
		t.type = actions.get(t.value, 'NO')
	t.value = int(t.value)
	return t

def t_arg_MULTIREG(t):
	r'MULTI(SOURCE|DEST|SOURCEDEST)([0-9]+)'
	t.value = t.lexer.lexmatch.group(1)
	return t

@TOKEN(r'XED_REG_' + id_chars + r'+')
def t_cond_REG(t):
	return t

@TOKEN(r'XED_ERROR_' + id_chars + r'+')
def t_cond_ERR(t):
	return t

@TOKEN(r'XED_' + id_chars + r'+')
def t_cond_ENUM(t):
	return t

@TOKEN(id_chars + '+')
def t_ID(t):
	t.type = keywords.get(t.value, 'ID')
	if 'INSTRUCTIONS' in t.value:
		t.type = 'INSID'
	if watch_a and t.value in a_s:
		t.type = a_s[t.value]
	if watch_access and t.value in accesses:
		t.type = accesses[t.value]
	if t.lexer.current_state()=='arg':
		if t.value in args:
			t.type = args[t.value]
		if t.value in xtypes:
			t.type = 'XTYPE'
	if watch_rsf and t.value in rsfs:
		t.type = rsfs[t.value]
	if watch_flag and t.value in flags:
		t.type = flags[t.value]
	if watch_action and t.value in actions:
		t.type = actions[t.value]
	return t

def t_ANY_error(t):
	pass

##--------------------------------------------------------------------------------------------------------------------##

## There is an ambiguity in the language between the following rules
##	new_bits : id newbits
##	parse_opcode_spec : id [ bit_pattern ]
##	parse_opcode_spec : id ( )
##	parse_opcode_spec : id EQ | NEQ number
## (flat|structured)_id : id id ( ) ::

def make_bits(n, l):
	return ('{:0' + str(l) + 'b}').format(n)

def p_start(p):
	'''start : newlines content'''
	p[0] = p[2]

def p_id(p):
	'''id : INSID
	      | ID'''
	p[0] = p[1]

def p_number_std(p):
	'''number : HEX
	          | BIN'''
	p[0] = p[1][0]
def p_number_bits(p):
	'''number : NO'''
	p[0] = p[1]

## newlines has to fold from right to left to avoid shift/reduce conflicts because of the ambiguity
def p_newlines(p):
	'''newlines : NEWLINE newlines
	            | NEWLINE'''
	pass


def p_tokens_none(p):
	'''tokens : '''
	p[0] = []
def p_tokens_item(p):
	'''tokens : tokens id'''
	p[0] = p[1] + p[2:3]

def p_bit_pattern_raw(p):
	'''bit_pattern : id "/" number
	               | id'''
	p[0] = p[1] * (p[3] if len(p)==4 else 1)
def p_bit_pattern_prefix(p):
	'''bit_pattern : BIN'''
	p[0] = make_bits(p[1][0], p[1][1])

def p_flag_action_t(p):
	'''flag_action_t : id "-" MOD
	                 | id "-" TST
	                 | id "-" U
	                 | id "-" ZERO
	                 | id "-" ONE
	                 | id "-" AH
	                 | id "-" POP'''
	p[0] = (p[1], p[3])


def p_eqp_lookup(p):
	'''eqp : id "(" ")"'''
	p[0] = ('nt_lookup_fn', p[1])
def p_eqp_reg(p):
	'''eqp : REG'''
	p[0] = ('reg', p[1])
def p_eqp_err(p):
	'''eqp : ERR'''
	p[0] = ('error', p[1])
def p_eqp_immc(p):
	'''eqp : ENUM
	       | number'''
	p[0] = ('imm_const', p[1])
def p_eqp_imm(p):
	'''eqp : id'''
	p[0] = ('imm', p[1].replace('_', ''))
	

def p_nep_reg(p):
	'''nep : REG'''
	p[0] = ('reg', p[1])
def p_nep_imm(p):
	'''nep : number'''
	p[0] = ('imm_const', p[1])

def p_flags_input_begin(p):
	'''flags_input : flag_action_t'''
	p[0] = [p[1]]
def p_flags_input_item(p):
	'''flags_input : flags_input flag_action_t'''
	p[0] = p[1] + p[2:3]


def p_watch_cond(p):
	'''watch_cond : '''
	p.lexer.begin('cond')
def p_unwatch_cond(p):
	'''unwatch_cond : '''
	p.lexer.begin('INITIAL')

def p_parse_one_operand_equals(p):
	'''parse_one_operand : id watch_cond EQ eqp unwatch_cond
	                     | id watch_cond NE nep unwatch_cond'''
	p[0] = (p[1], p[3], p[4][0], p[4][1])
def p_parse_one_operand_imm(p):
	'''parse_one_operand : MEMX
	                     | IMMX
	                     | AGEN
	                     | RELBR
	                     | PTR'''
	p[0] = (p[1], 'imm_const', '1')
def p_parse_one_operand_reset(p):
	'''parse_one_operand : RESET'''
	p[0] = (p[1], 'xed_reset', '')
	vis = 'SUPP'
def p_parse_one_operand_flag(p):
	'''parse_one_operand : id'''
	p[0] = (p[1], 'flag', '')

def p_access(p):
	'''access : R
	          | W
	          | RW
	          | CRW
	          | RCW'''
	p[0] = p[1]

def p_arg_vis(p):
	'''arg : IMPL
	       | SUPP
	       | EXPL
	       | ECOND'''
	p[0] = (0, p[1])
def p_arg_multireg(p):
	'''arg : MULTIREG'''
	p[0] = (3, p[1])
def p_arg_convert(p):
	'''arg : TXT EQ id'''
	p[0] = (4, tuple(p[1:]))
def p_arg_oc2(p):
	'''arg : id'''
	p[0] = (1, p[1])
def p_arg_xtype(p):
	'''arg : XTYPE'''
	p[0] = (2, p[1])

def p_watch_action(p):
	'''watch_action : "["'''
	global watch_action
	watch_action = True
def p_unwatch_action(p):
	'''unwatch_action : "]"'''
	global watch_action
	watch_action = False

def p_flag_rec_t(p):
	'''flag_rec_t : FLAGQUAL FLAGSPEC watch_action flags_input unwatch_action
	              | FLAGSPEC watch_action flags_input unwatch_action'''
	p[0] = (p[0] if len(p)==6 else None, p[3 if len(p)==5 else 4])


## ID and INSID can't be merged because they must not be reduced to resolve the ambiguity
def p_parse_opcode_spec_bin(p):
	'''parse_opcode_spec : BIN'''
	p[0] = list(make_bits(p[1][0], p[1][1]))
def p_parse_opcode_spec_hex(p):
	'''parse_opcode_spec : HEX'''
	p[0] = list(make_bits(p[1][0], p[1][1]))
def p_parse_opcode_spec_binding(p):
	'''parse_opcode_spec : ID "[" bit_pattern "]"
	                     | INSID "[" bit_pattern "]"'''
	p[0] = [(p[1], x) for x in p[3]]
	# validate_field_width
def p_parse_opcode_spec_nt(p):
	'''parse_opcode_spec : ID "(" ")"
	                     | INSID "(" ")"'''
	p[0] = [p[1]]
def p_parse_opcode_spec_restriction(p):
	'''parse_opcode_spec : ID EQ number
	                     | INSID EQ number
	                     | ID NE number
	                     | INSID NE number'''
	p[0] = [tuple(p[1:])]

def p_watch_access(p):
	'''watch_access : '''
	global watch_access
	watch_access = True
def p_unwatch_access(p):
	'''unwatch_access : '''
	global watch_access
	watch_access = False

def p_watch_arg(p):
	'''watch_arg : '''
	p.lexer.begin('arg')
def p_unwatch_arg(p):
	'''unwatch_arg : '''
	p.lexer.begin('INITIAL')

def p_parse_operand_spec_item(p):
	'''parse_operand_spec : parse_one_operand watch_access COLON access unwatch_access watch_arg COLON arg COLON arg COLON arg unwatch_arg
	                      | parse_one_operand watch_access COLON access unwatch_access watch_arg COLON arg COLON arg unwatch_arg
	                      | parse_one_operand watch_access COLON access unwatch_access watch_arg COLON arg unwatch_arg
	                      | parse_one_operand watch_access COLON access unwatch_access
	                      | parse_one_operand watch_access COLON
	                      | parse_one_operand'''
	vis = 'DEFAULT'
	oc2 = None
	xtype = 'INVALID'
	multireg = 0
	cvt = []
	if len(p) > 3:
		for x in p[8::2]:
			if x[0]==0:
				vis = x[1]
			if x[0]==1:
				oc2 = x[1]
			if x[0]==2:
				xtype = x[1]
			if x[0]==3:
				multireg = x[1]
			if x[0]==4:
				cvt.append(x[1])
	p[0] = (p[1], p[4] if len(p) > 4 else 'r', vis, oc2, \
		widths[oc2.upper()] if oc2 and xtype=='INVALID' else xtype, multireg, cvt)

def p_flag_info_t_begin(p):
	'''flag_info_t : flag_rec_t'''
	p[0] = [p[1]]
def p_flag_info_t_item(p):
	'''flag_info_t : flag_info_t "," flag_rec_t'''
	p[0] = p[1] + p[3:4]


## the first ID and INSID can't be merged because this rule would be conflicting with itself
def p_flat_id_type(p):
	'''flat_id : INSID ID "(" ")" NTSP
	           | ID ID "(" ")" NTSP'''
	p[0] = [p[2], p[1]]
def p_flat_id_none(p):
	'''flat_id : ID "(" ")" NTSP'''
	p[0] = [p[1], None]

## new_bits has to fold right to left because of OTHERWISE and the ambiguity
def p_new_bits_none(p):
	'''new_bits : '''
	p[0] = []
def p_new_bits_otherwise(p):
	'''new_bits : OTHERWISE'''
	p[0] = [p[1]]
	# pass
def p_new_bits_item(p):
	'''new_bits : parse_opcode_spec new_bits'''
	p[0] = p[1] + p[2]
## ID and INSID can't be merged because of the ambiguity
def p_new_bits_state(p):
	'''new_bits : ID new_bits
	            | INSID new_bits'''
	if p[1] in state:
		p[0] = state[p[1]] + p[2]
	else:
		p[0] = list(p[1].replace('_', '')) + p[2]

def p_bindings_none(p):
	'''bindings : '''
	p[0] = []
def p_bindings_item(p):
	'''bindings : bindings parse_operand_spec'''
	p[0] = p[1] + p[2:3]

## the first ID and INSID can't be merged because this rule would be conflicting with itself
def p_structured_id_type(p):
	'''structured_id : INSID INSID "(" ")" NTSP
	                 | ID INSID "(" ")" NTSP'''
	p[0] = [p[2], p[1]]
def p_structured_id_none(p):
	'''structured_id : INSID "(" ")" NTSP'''
	p[0] = [p[1], None]

def p_watch_rsf(p):
	'''watch_rsf : '''
	global watch_rsf
	watch_rsf = True
def p_unwatch_rsf(p):
	'''unwatch_rsf : '''
	global watch_rsf
	watch_rsf = False

def p_eat_everything(p):
	'''eat_everything : '''
	p.lexer.begin('eat')
def p_stop_eating(p):
	'''stop_eating : '''
	p.lexer.begin('INITIAL')

def p_watch_flags(p):
	'''watch_flag : '''
	global watch_flag
	watch_flag = True
def p_unwatch_flag(p):
	'''unwatch_flag : '''
	global watch_flag
	watch_flag = False

def p_read_structured_flexible_begin(p):
	'''read_structured_flexible : "{" watch_rsf newlines'''
	p[0] = [None, None, 'DEFAULT', 'DEFAULT', None, [], None, [], None, None, 0] + [None] * 6 + [[], {}]
def p_read_structured_flexible_pat(p):
	'''read_structured_flexible : read_structured_flexible PAT unwatch_rsf COLON new_bits watch_rsf newlines'''
	p[0] = p[1]
	p[0][5]+= p[5:6]
def p_read_structured_flexible_opnds(p):
	'''read_structured_flexible : read_structured_flexible OPNDS unwatch_rsf COLON bindings watch_rsf newlines'''
	p[0] = p[1]
	p[0][7]+= p[5:6]
def p_read_structured_flexible_iform(p):
	'''read_structured_flexible : read_structured_flexible IFORM unwatch_rsf COLON id watch_rsf newlines'''
	p[0] = p[1]
	p[0][17]+= p[5:6]
def p_read_structured_flexible_icls(p): # That's the name
	'''read_structured_flexible : read_structured_flexible ICLS unwatch_rsf COLON id watch_rsf newlines'''
	p[0] = p[1]
	p[0][0] = p[5]
def p_read_structured_flexible_cat(p):
	'''read_structured_flexible : read_structured_flexible CAT unwatch_rsf COLON id watch_rsf newlines'''
	p[0] = p[1]
	p[0][2] = p[5]
def p_read_structured_flexible_cpl(p):
	'''read_structured_flexible : read_structured_flexible CPL unwatch_rsf COLON number watch_rsf newlines'''
	p[0] = p[1]
	p[0][11] = p[5]
def p_read_structured_flexible_ext(p):
	'''read_structured_flexible : read_structured_flexible EXT unwatch_rsf COLON id watch_rsf newlines'''
	p[0] = p[1]
	p[0][3] = p[5]
	# AVX512EVEX
def p_read_structured_flexible_isa(p):
	'''read_structured_flexible : read_structured_flexible ISA unwatch_rsf COLON id watch_rsf newlines'''
	p[0] = p[1]
	p[0][4] = p[5]
def p_read_structured_flexible_attr(p):
	'''read_structured_flexible : read_structured_flexible ATTR unwatch_rsf COLON tokens watch_rsf newlines'''
	p[0] = p[1]
	p[0][6] = p[5]
def p_read_structured_flexible_ver(p):
	'''read_structured_flexible : read_structured_flexible VER unwatch_rsf COLON number watch_rsf newlines'''
	p[0] = p[1]
	p[0][10] = p[5]
def p_read_structured_flexible_flags(p):
	'''read_structured_flexible : read_structured_flexible FLAGS unwatch_rsf watch_flag COLON flag_info_t unwatch_flag watch_rsf newlines'''
	p[0] = p[1]
	p[0][9] = p[6]
# def p_read_structured_flexible_ucode(p):
	# '''read_structured_flexible : read_structured_flexible UC unwatch_rsf COLON ??? watch_rsf newlines'''
	# p[0] = p[1]
	# p[0][8] = p[???]
def p_read_structured_flexible_com(p):
	'''read_structured_flexible : read_structured_flexible COM unwatch_rsf COLON eat_everything EATER stop_eating watch_rsf newlines'''
	p[0] = p[1]
	p[0][12] = p[6]
def p_read_structured_flexible_exc(p):
	'''read_structured_flexible : read_structured_flexible EXC unwatch_rsf COLON eat_everything EATER stop_eating watch_rsf newlines'''
	p[0] = p[1]
	p[0][13] = p[6]
def p_read_structured_flexible_disasm(p):
	'''read_structured_flexible : read_structured_flexible DISASM unwatch_rsf COLON id watch_rsf newlines'''
	p[0] = p[1]
	p[0][14] = p[5]
def p_read_structured_flexible_disasmi(p):
	'''read_structured_flexible : read_structured_flexible DISASMI unwatch_rsf COLON eat_everything EATER stop_eating watch_rsf newlines'''
	p[0] = p[1]
	p[0][15] = p[6]
def p_read_structured_flexible_disasmv(p):
	'''read_structured_flexible : read_structured_flexible DISASMSV unwatch_rsf COLON id watch_rsf newlines'''
	p[0] = p[1]
	p[0][16] = p[5]
def p_read_structured_flexible_uname(p):
	'''read_structured_flexible : read_structured_flexible UNAME unwatch_rsf COLON id watch_rsf newlines'''
	p[0] = p[1]
	p[0][1] = p[5]
def p_read_structured_flexible_other(p):
	'''read_structured_flexible : read_structured_flexible id unwatch_rsf COLON id watch_rsf newlines'''
	p[0] = p[1]
	p[0][18][p[2]] = p[5]


def p_watch_a(p):
	'''watch_a : '''
	global watch_a
	watch_a = True
def p_unwatch_a(p):
	'''unwatch_a : newlines'''
	global watch_a
	watch_a = False

## flat_input has to fold from left to right because of the ambiguity
def p_flat_input_begin(p):
	'''flat_input : flat_id newlines'''
	p[0] = p[1]
def p_flat_input_item(p):
	'''flat_input : flat_input new_bits watch_a "|" bindings unwatch_a'''
	p[0] = p[1] + [(p[2], p[5])]

## structured_input has to fold from left to right because of the ambiguity
def p_structured_input_begin(p):
	'''structured_input : structured_id newlines'''
	p[0] = p[1]
def p_structured_input_deletes(p):
	'''structured_input : structured_input UDEL COLON id newlines
	                    | structured_input DEL COLON id newlines'''
	p[0] = p[1] + [(p[2], p[4])]
def p_structured_input_item(p):
	'''structured_input : structured_input read_structured_flexible unwatch_rsf "}" newlines'''
	p[0] = p[1] + [tuple(p[2])]



## content has to fold from right to left because of the ambiguity
def p_content_none(p):
	'''content : '''
	p[0] = {}
def p_content_flat(p):
	'''content : flat_input content'''
	p[0] = p[2]
	if p[1][0] in p[0]:
		if p[0][p[1][0]][0]!=p[1][1]:
			print('WARNING: conflicting types', p[1][1], p[0][p[1][0]][0])
	else:
		p[0][p[1][0]] = [p[1][1]]
	p[0][p[1][0]]+= p[1][2:]
def p_content_structured(p):
	'''content : structured_input content'''
	p[0] = p[2]
	if p[1][0] in p[0]:
		if p[0][p[1][0]][0]!=p[1][1]:
			print('WARNING: conflicting types', p[1][1], p[0][p[1][0]][0])
	else:
		p[0][p[1][0]] = (p[1][1], [], {})
	for x in p[1][2:]:
		if len(x)==2:
			p[0][p[1][0]][1].append(x)
		elif x[0] not in p[0][p[1][0]][2] or p[0][p[1][0]][2][x[0]][0] < x[10]:
			p[0][p[1][0]][2][x[0]] = (x[10], [x[1:]])
		elif p[0][p[1][0]][2][x[0]][0]==x[10]:
			p[0][p[1][0]][2][x[0]][1].append(x[1:])


def p_error(p):
	if p:
		print('generators', p)


def init(st, ws, xt):
	global state, widths, xtypes
	state = st
	widths = ws
	xtypes = xt

from ply.yacc import yacc
parser = yacc(tabmodule='generators_table')

def parse(files):
	try:
		file = open(files.__next__(), buffering=1)
		line = file.readline()
		while not line:
			file.close()
			file = open(files.__next__(), buffering=1)
			line = file.readline()

		def t_ANY_eof(t):
			nonlocal file, files
			token = None
			try:
				while file and not token:
					line = file.readline()
					while not line:
						file.close()
						file = None
						file = open(files.__next__(), buffering=1)
						line = file.readline()
					lexer.input(line)
					token = lexer.token()
			finally:
				return token

		lexer = lex()
		generators = parser.parse(line, lexer=lexer)
		for (k, v) in generators.items():
			if 'INSTRUCTIONS' in k:
				icls = set()
				unames = set()
				for (type, deleted) in v[1]:
					if type=='DELETE':
						icls.add(deleted)
					if type=='UDELETE':
						unames.add(deleted)
				generators[k] = (v[0], {k: [x for x in v[1] if not (x[0] in icls or x[1] in unames)] \
					for (k, v) in v[2].items()})
		return generators
	except StopIteration:
		return None