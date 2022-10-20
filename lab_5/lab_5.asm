.data
A_bcd: .byte 0x99 0x98 0x19  # записали число 199907 в упакованном формате через шестнадцатеричную запись
A_sign: .byte 0 # если знак отрицательный, пишем 1
A_size: .byte 3

B_bcd: .byte 0x05 # записали число 0503 в упакованном формате через шестнадцатеричную запись
B_sign: .byte 0x0
B_size: .byte 2

C_bcd: .byte 0 0 0 0
C_sign: .byte 0x0
C_size: .byte 4

A_unpack: .byte 0 0 0 0 0 0 0
A_un_size: .byte 7 # размер распакованного числа равен 2*A_size + 1, для корректного вывода сообщения с учётом знака числа

B_unpack: .byte 0 0 0
B_un_size: .byte 3

C_unpack: .byte 0 0 0 0 0 0 0 0 0
C_un_size: .byte 9

A_reverse: .byte 0 0 0 0 0 0 0
B_reverse: .byte 0 0

mes_n: .asciiz "\n"
string: .asciiz ""

.text
# в начале реализуем процедуру перевода упакованного числа в неупакованное
Prepare:
	# для передачи данных в процедуру используем регистры a
	la $a0, A_bcd
	la $a1, A_unpack
	la $a2, A_size
	lb $a2, ($a2)
	jal Proc_To_Unpack
	
	la $a0, B_bcd
	la $a1, B_unpack
	la $a2, B_size
	lb $a2, ($a2)
	jal Proc_To_Unpack

# начинаем подготовку к вызову процедуры сложения
# для упрощения работы сначала заполняем в переменную C большую из переменных
	comparison:
	la $t0, A_unpack
	la $t1, A_un_size
	lb $t1, ($t1)
	la $t2, B_unpack
	la $t3, B_size
	lb $t3, ($t3)
	
	subu $t4, $t3, $t1
	la $a1, C_unpack
	bgtz $t4, copy_second
	copy_first:
	move $v0, $t3
	subu $v1, $t1, $t3
	move $a0, $t0
	move $a2, $t1
	j continue
	copy_second:
	move $v0, $t1
	subu $v1, $t3, $t1
	move $a0, $t2
	move $a2, $t3
	
	continue:
	jal Proc_Copy # в результате в C_unpack запишется большая по модулю из переменных

Addition_function:
	move $t0, $v0 # записываем размерность меньшего числа
	li $t1, 0 # используем как счётчик
	li $t2, 0 # используем для хранения переноса
	li $t3, 0 # получение байта из первой переменной
	li $t4, 0 # получение байта из второй переменной
	
addition_loop:
	beq $t0, $t1, end_loop
	la $t3, A_unpack # получаем адрес начала массива числа
	addu $t3, $t3, $t1 # перемещаемся к адресу нужного байта
	lbu $t3, ($t3) # перезаписываем в t3 значение этого байта
	
	beq $t2, 0, without_transfer_from_junior
	addu $t3, $t3, $t2
	
	without_transfer_from_junior:
	li $t2, 0
	la $t4, B_unpack # получаем адрес начала массива числа
	addu $t4, $t4, $t1 # перемещаемся к адресу нужного байта
	lbu $t4, ($t4) # перезаписываем в t3 значение этого байта
	
	addu $t5, $t3, $t4 # записали в t5 сумму байтов двух чисел
	andi $t3, $t5, 0x0F # перезаписываем в t3 младшую тетраду
	subu $t4, $t3, 0xA
	bltz $t4, no_adjustment # если младшая тетрада < 10, переходим на метку
	addiu $t5, $t5, 0x6 # добавляем корректирующую величину
	
	no_adjustment:
	andi $t4, $t5, 0xF0 
	srl $t4, $t4, 4 # перезаписываем в t4 старшую тетраду
	beq $t4, 0, no_transfer
	move $t2, $t4 # запоминаем значение переноса в регистр 
	andi $t5, $t5, 0x0F # обнуляем старшую тетраду
	
	no_transfer:
	la $t6, C_unpack
	addu $t6, $t6, $t1
	sb $t5, ($t6) # запоминаем в переменную C значение байта
	
	addi $t1, $t1, 1
	j addition_loop
end_loop:
	# теперь, когда этот цикл завершился, нужно рассмотреть старшие байты большего числа на предмет переноса
	beq $t2, 0, end_function
	
	addu $t0, $t1, $v1
last_loop:
	beq $t0, $t1, end_function
	
	la $t6, C_unpack
	addu $t6, $t6, $t1
	lb $t7, ($t6)
	
	beq $t2, 0, without_transfer_last
	addu $t7, $t7, $t2
	
	without_transfer_last:
	li $t2, 0
	andi $t3, $t7, 0x0F # перезаписываем в t3 младшую тетраду
	subu $t4, $t3, 0xA
	bltz $t4, no_adjustment_last # если младшая тетрада < 10, переходим на метку
	addiu $t7, $t7, 0x6 # добавляем корректирующую величину
	
	no_adjustment_last:
	andi $t4, $t7, 0xF0 
	srl $t4, $t4, 4 # перезаписываем в t4 старшую тетраду
	beq $t4, 0, no_transfer_last
	move $t2, $t4 # запоминаем значение переноса в регистр 
	andi $t7, $t7, 0x0F # обнуляем старшую тетраду
	
	no_transfer_last:
	sb $t7, ($t6) # запоминаем в переменную C значение байта
	
	addi $t1, $t1, 1 # увеличиваем счётчик
	j last_loop
	end_function:
	
	la $a0, C_unpack
	la $a1, C_un_size
	lb $a1, ($a1)
	la $a2, string
	la $a3, A_sign
	lb $a3, ($a3)
	jal Proc_Print
	
	la $a0, string
	la $v0, 4
	syscall
	
Exit:
	li $v0, 10
	syscall

#----------- процедура копирования неупакованного числа в другую переменную --------------#
Proc_Copy:
	# принимаем три переменные: два адреса и размер
	move $t0, $a0 # адрес копируемой переменной
	move $t1, $a1 # адрес пустой переменной
	move $t2, $a2 # размерность
	
	li $a0, 0
	li $a1, 0
	li $a2, 0
	li $t3, 0 # используем как счётчик
	copy_loop:
	beq $t2, $t3, exit_copy_proc
	move $t4, $t0 # получаем адрес начала массива числа
	addu $t4, $t4, $t3 # перемещаемся к адресу нужного байта
	lbu $t4, ($t4) # перезаписываем в t4 значение этого байта
	
	move $t5, $t1 # получаем адрес байта, куда запишем результат
	addu $t5, $t5, $t3 # перемещаемся к адресу нужного байта
	sb $t4, ($t5)
	
	addi $t3, $t3, 1
	j copy_loop
	exit_copy_proc:
	li $t0, 0
	li $t1, 0
	li $t2, 0
	li $t3, 0
	li $t4, 0
	li $t5, 0
	jr $ra
	
	
#----------- процедура перевода неупакованного числа в обратный код --------------#
Proc_To_Reverse:
	move $t0, $a0 # = адресу неупакованного числа
	move $t1, $a1 # = адрес обратного числа (пустой переменной)
	move $t2, $a2 # - размер неупакованного числа
	#subi $t2, $t2, 1 # учитываем лишний разряд для корректного вывода минуса (он нам не нужен)
	
	li $a0, 0
	li $a1, 0
	li $a2, 0
	li $t3, 0 # используем как счётчик

	rev_loop:
	beq $t2, $t3, exit_rev_proc
	move $t4, $t0 # получаем адрес начала массива числа
	addu $t4, $t4, $t3 # перемещаемся к адресу нужного байта
	lbu $t4, ($t4) # перезаписываем в t4 значение этого байта
	li $t5, 9
	subu $t4, $t5, $t4 # получаем обратное число
	
	move $t5, $t1 # получаем адрес байта, куда запишем результат
	addu $t5, $t5, $t3 # перемещаемся к адресу нужного байта
	sb $t4, ($t5)
	
	addi $t3, $t3, 1
	j rev_loop

	exit_rev_proc:
	li $t0, 0
	li $t1, 0
	li $t2, 0
	li $t3, 0
	li $t4, 0
	li $t5, 0
	jr $ra	

#--------------- процедура записи неупакованного числа в строку ----------------#
Proc_Print:
# реализуем процедуру печати числа
	move $t0, $a0 # = адресу неупакованного числа
	move $t1, $a1 # = размер неупакованного числа
	move $t2, $a2 # = адресу переменной, в которую запишется сообщение
	move $t3, $a3 # = знаку числа
	
	li $a0, 0
	li $a1, 0
	li $a2, 0
	li $t4, 0 # используем как счётчик
	move $t7, $t1
	subi $t7, $t7, 1
	
	print_loop:
	beq $t1, $t4, end_print_loop
	
	move $t5, $t0
	addu $t5, $t5, $t4
	lb $t5, ($t5) # получаем содержимое нужного байта – число
	addu $t5, $t5, 0x30 # прибавляем к числу 30h – переводим число в символ
	
	move $t6, $t2
	addu $t6, $t6, $t7
	sb $t5, ($t6) 
	
	subi $t7, $t7, 1 # уменьшаем счётчик на 1
	addi $t4, $t4, 1
	j print_loop 
	
	end_print_loop:
	# тут выводим знак числа, если он отрицательный
	beq $t3, 0, exit_print_proc 
	print_sign:
	addu $t3, $t3, 0x2C # получаем знак '-'
	move $t6, $t2
	sb $t3, ($t6) 
	
	exit_print_proc:
	li $t0, 0
	li $t1, 0
	li $t2, 0
	li $t3, 0
	li $t4, 0
	li $t5, 0
	jr $ra

#------------- процедура перевода упакованного числа в неупакованное -------------#
Proc_To_Unpack:
	move $t0, $a0 # = адресу упакованного числа
	move $t1, $a1 # = адрес неупакованного числа (пустой переменной)
	move $t2, $a2 # - размер упакованного числа
	
	li $a0, 0
	li $a1, 0
	li $a2, 0
	li $t3, 0 # используем как счётчик
	li $t4, 0 # используем как счётчик для неупакованной переменной
	
	unpck_loop:
	beq $t2, $t3, end_unpck_loop
	li $t5, 0 # используем для хранения байта
	li $t6, 0 # t6 используем для хранения тетрады
	li $t7, 0 # t7 используем для хранения актуального адреса байта unpack
	
	move $t5, $t0 # получаем адрес начала массива числа A
	addu $t5, $t5, $t3 # перемещаемся к адресу нужного байта
	lbu $t5, ($t5) # перезаписываем в t5 значение этого байта
	
	move $t7, $t1 # определяем адрес неупакованного числа, куда запишем результат
	addu $t7, $t7, $t4
	addi $t4, $t4, 1
	
	andi $t6, $t5, 0x0F # выделяем младшую тетраду в регистр t6
	sb $t6, ($t7) # сохраняем младшую тетраду в байт неупакованного числа
	addi $t7, $t7, 1 # перемещаемся к следующему байту переменной unpack
	
	andi $t6, $t5, 0xF0 # теперь записываем в t6 старшую тетраду
	srl $t6, $t6, 4 # смещаем на 4 бита
	sb $t6, ($t7) # сохраняем тетраду в байт неупакованного числа	
	
	addi $t4, $t4, 1 # снова увеличиваем счётчик для неупакованного числа
	addi $t3, $t3, 1 # увеличиваем счётчик на 1
	j unpck_loop
	
	end_unpck_loop:
	# неупакованное число получили
	# теперь выходим из проедуры, предварительно очистив все регистры
	
	li $t0, 0
	li $t1, 0
	li $t2, 0
	li $t3, 0
	li $t4, 0
	li $t5, 0
	li $t6, 0
	li $t7, 0
	exit_unpck_proc:
	jr $ra # выходим из процедуры
	