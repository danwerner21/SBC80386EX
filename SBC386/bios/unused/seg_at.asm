_BDA_ SEGMENT AT 040H
	ASSUME	CS:_BDA_,DS:_BDA_

	public	dev_serial
dev_serial:
	DW	?,?,?,?
	public	dev_parallel
dev_parallel:
	DW	?,?,?,?
LTH	EQU	*


_BDA_	ENDS

END
