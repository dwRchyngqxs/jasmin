# enums = []

import os
import configs_parser
for (dir, _, paths) in os.walk('datafiles'):
	for file in paths:
		if file[-4:]=='.cfg':
			with open(os.path.join(dir, file), buffering=1) as f:
				for line in f:
					configs_parser.parse(line, dir)
		# if file[-8:]=='enum.txt':
			# enums.append(os.path.join(dir, file))
configs = configs_parser.configs
del configs_parser
del os

del configs['enc-patterns']
del configs['enc-dec-patterns']
del configs['enc-instructions']

##--------------------------------------------------------------------------------------------------------------------##

import fields_parser
for file in configs['fields']:
	with open(file, buffering=1) as f:
		for line in f:
			fields_parser.parse(line)
del configs['fields']
fields = fields_parser.fields
del fields_parser


import registers_parser
for file in configs['registers']:
	with open(file, buffering=1) as f:
		for line in f:
			registers_parser.parse(line)
del configs['registers']

registers = {}
for regl in registers_parser.registers.values():
	min = (registers_parser.registers[regl[0][3][0]][0][2], regl[0])
	for reg in regl:
		sz = registers_parser.registers[reg[3][0]][0][2]
		if sz > min[0]:
			min = (sz, reg)
	registers[min[1][0]] = min[1]
del registers_parser


import widths_parser
for file in configs['widths']:
	with open(file, buffering=1) as f:
		for line in f:
			widths_parser.parse(line)
del configs['widths']
widths = widths_parser.widths
del widths_parser


import extra_widths_parser
for file in configs['extra-widths']:
	with open(file, buffering=1) as f:
		for line in f:
			extra_widths_parser.parse(line)
del configs['extra-widths']
extra_widths_nt = extra_widths_parser.extra_widths_nt
extra_widths_reg = extra_widths_parser.extra_widths_reg
extra_widths_imm_const = extra_widths_parser.extra_widths_imm_const
del extra_widths_parser


import element_type_base_parser
for file in configs['element-type-base']:
	with open(file, buffering=1) as f:
		for line in f:
			element_type_base_parser.parse(line)
del configs['element-type-base']
element_type_base = element_type_base_parser.element_type_base
del element_type_base_parser


import element_types_parser
for file in configs['element-types']:
	with open(file, buffering=1) as f:
		for line in f:
			element_types_parser.parse(line)
del configs['element-types']
element_types = element_types_parser.element_types
del element_types_parser


import pointer_names_parser
for file in configs['pointer-names']:
	with open(file, buffering=1) as f:
		for line in f:
			pointer_names_parser.parse(line)
del configs['pointer-names']
pointer_names = pointer_names_parser.pointer_names
del pointer_names_parser


import state_parser
for file in configs['state']:
	with open(file, buffering=1) as f:
		for line in f:
			state_parser.parse(line)
del configs['state']
state = state_parser.state
del state_parser


from itertools import chain
import generators_parser
generators_parser.init(state, widths, element_types)
generators = generators_parser.parse(chain(configs['dec-spine'], configs['dec-patterns'], configs['dec-instructions']))
del generators_parser
del chain


print('TODO: call_chipmodel')
# import chip_models_parser
for file in configs['chip-models']:
	with open(file) as f:
		for line in f:
			# chip_models_parser.parse(line)
			# handle eof for continuation
			pass
del configs['chip-models']
# chip_models = chip_models_parser.chip_models
# del chip_models_parser


print('TODO: call_ctables')
# import conversion_table_parser
# nonterminals
for file in configs['conversion-table']:
	with open(file) as f:
		for line in f:
			# conversion_table_parser.parse(line)
			pass
# conversion_table = conversion_table_parser.conversion_table
del configs['conversion-table']


print('TODO: ild_scanners')
# configs['ild-scanners'] = {w[0] % {'xed_dir': '.'}: int(w[1]) for file in map(lambda file: filter(lambda x: len(x)==2, map(lambda line: \
#	comment.sub('', line).strip().split(), open(file, buffering=1))), configs['ild-scanners']) for w in file}
del configs['ild-scanners']


import cpuid_parser
for file in configs['cpuid']:
	with open(file, buffering=1) as f:
		for line in f:
			cpuid_parser.parse(line)
del configs['cpuid']
cpuid = cpuid_parser.cpuid
del cpuid_parser

del configs

##--------------------------------------------------------------------------------------------------------------------##

# print('FIELDS')
# print(fields)

# print('REGISTERS')
# print(registers)

# print('WIDTHS')
# print(widths)

# print('EXTRA-WIDTHS')
# print(extra_widths_nt)
# print(extra_widths_reg)
# print(extra_widths_imm_const)

# print('ELEMENT-TYPE-BASE')
# print(element_type_base)

# print('ELEMENT-TYPES')
# print(element_types)

# print('POINTER-NAMES')
# print(pointer_names)

# print('STATE')
# print(state)

# Finish that later
print('DEC-SPINE + DEC-PATTERNS + DEC-INSTRUCTIONS')
print(generators)

# TODO
# print('CHIP-MODELS')
# print(chip_models)

# TODO
# print('CONVERSION-TABLE')
# print(conversion_table)

# TODO
# print('ILD-SCANNERS')
# print(ild_scanners)

# print('CPUID')
# print(cpuid)

# UNSEEN
# print('ENUMS')
# print(enums)