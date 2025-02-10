# =============================================
# SOKOBAN by linryan 5
# 
# turn off function nesting too deep when marking this please.
# yes that issue is here.
# =============================================
# Enhancement 1: Multiplayer (line  1296 - line 1547)
#	- Allows you to play with multiple friends, and keep track of whos better via a leaderboard.
# 	- Some other labels were also changed, with some lines added here and there
# 	- Other things included in this enhancement were a conceed button, restart (the board) button,
# 	  and the hard restart button.
#	- Important features of this include Leaderboard, save and loading grid states.
#	- Lesser features include player indexing, clearing memory
#	- Impletmented as the following:	
#		- Clear the player id, moves heap on startup
#		- For every move, add it to a move counter
# 		- Once a game is complete, add the player id to a heap and the amount of moves they made to another
#			- Sorted as a bubble sort of sorts (if the player's moves are greater than the curr index,
#				then insert the player at that spot and push all other players down a spot)
#		- Once the game ends:
#			- Print the leader board and gameover screens
#			- Output the Leaderboard by referencing both the moves heap, and the player id heap.
# =============================================
# Enhancement 2: Multiplayer Replay (line  1557 - line 2022)
#	- Allows you to view replays of players' games.
# 	- Some other labels were also changed, with some lines added here and there
# 	- This enhancement has more copy and pasting that the entirety of Wyoming.
# 	- Important features include byte packing, masking control codes
#	- Impletmented as the following:	
#		- Clear the replay heap upon startup
#		- For every move, add it to a heap in memory
# 		- Assign a unique code to it, and assign it to half a byte in memory
#		- Once a game ends, check if the amount of moves is odd/even
#			- If even, then do nothing
#			- If odd, increment the byte tracker by 1 byte as to not write another player's movement into
#				the previous player's (acting as 0 buffer)
#		- Once the game is done:
#			- Ask player for a replay
# 			- If the player wants a replay, then ask for a number between 1 and # of players.
#				- Go back to asking for replay if an invalid number was entered
#			- load the grid into the starting state
#			- Find the correct memory address as to where the first move is stored
#			- Decode the byte into two control ops
# 			- Run these against a modified version of MainLoop (The main game loop) and process them.
# 			- Continue until the move limit has been reached (which has been divided by 2 since we have two moves per byte, rounded up)
#			- Ask player for a replay, and repeat ad nauseam until satisfied.
# =============================================
# Psuedorandomness: LCG (line  1251 - line 1265)
# 
# Citation: Derrick Henry Lehmer. Linear Congruential Generator. 
# Retrieved October 10, 2024 from https://en.wikipedia.org/wiki/Linear_congruential_generator
# =============================================
.data
seed:		.word 82672653
charStr:	.string "P"
boxStr:		.string "O"
targetStr:	.string "X"
emptySpStr: .string "."
tarCharStr:	.string "K"
tarBoxStr:	.string "V"
wallStr:	.string "+"
newline:	.string "\n"
playInput:	.string "\nEnter your input: (Uses WASD controls),\n or type 'r' to reset, 'q' to exit the program,\n 'c' to conceed and pass to the other player, or 'p' to hard reset the program.\n"
invInput:	.string "\nInvalid input, enter as w,a,s,d, without captialization.\n"
cantMove:	.string "\nCan't move in specified direction!\n"
winMSG1:	.string "\nYou have completed the game!\n"
promptUSER: .string "\nWould you like to play another game? Type any key to confirm, 'n' if not.\n"
pNumUsers:	.string "\nHow many players are playing? (default is 1)\n"
TimeFor:	.string "\nTime for player "
ToPlay:		.string " to play!\n"
leaderboard:.string "\nLeaderboard:\n\n"
playernum:	.string " Player #"
colon:		.string ": "
nummoves:	.string " moves.\n"
replayPrmpt:.string "\nWould you like to watch any replays of your games? Type any key to confirm, 'n' if not.\n"
replayNum:	.string "\nWhich Player would you like to watch the replay of?\n"
invReplay:	.string "\nInvalid player number!\n"
strtReplay: .string "This is the replay for player number: "
GameOver:	.string "\nGAME OVER\n"
DNF:		.string "DNF.\n"
period:		.string "."
w:			.string "w"
a:			.string "a"
s:			.string "s"
d:			.string "d"
r:			.string "r"
hardR:		.string "p"
q:			.string "q"
c:			.string "c"
n:			.string "n"
gridsize:   .byte 8,8
character:  .byte 0,0
box:        .byte 0,0
target:     .byte 0,0
MemoryShift:.byte 0,0,0 
countPlayer:.word 1
numPlayers:	.word 1
move: 		.word 0
globlShift: .word 0

# Everthing must be loaded before grid.
grid:		.byte 0,0,0,0,0
.text
.global _start


_start:
	jal notrand
	la t0, seed
	sw a0, (t0)
	
	# Clear countPlayer, numPlayers, move:
	mv sp, x0
	la t0, countPlayer
	li t1, 1
	sw t1, (t0)
	la t0, numPlayers
	sw t1, (t0)
	la t0, move
	sw x0, (t0)
	la t0, globlShift
	sw x0, (t0)
	
	# 0 is emptyspace, 1 is player, 2 is box, 3 is target,
	# 4 is wall, 5 is target + Box, 6 is player + target.
	jal clearGridMemory
	jal clearLeaderboard
	jal ClearReplay
	jal initGrid
	
	
	
	# Load boardsize
	la t0, gridsize
	lb t1, (t0)
	lb t2, 1(t0)
	la a2, character
	jal randpos 
	li a3, 1
	mv a1, a2
	la a0, grid
	jal setGrid
	# Ensrue that they don't overlap.
	la a2, box
	USUALBOX:
		la t0, gridsize
		lb t1, (t0)
		lb t2, 1(t0)
		jal randpos
	CHECKIFCORNER:
		la t0, gridsize
		lb t1, 1(t0) #col num (switch if needed.)
		addi t1, t1, -1
		lb t2, (t0) # row num (switch if needed.)
		addi t2, t2, -1
		la t0, box
		lb t3, 1 (t0) #col (switch if needed.)
		lb t4, (t0)#row (switch if needed.)
		# Check if it is in the top or bottom row.
		beq t4, x0, TOP
		beq t4, t1, BOTTOM
		j CONTINUEBOX
		TOP:
			beq t3, x0, USUALBOX
			beq t3, t2, USUALBOX
			j CONTINUEBOX
		BOTTOM:
			beq t3, x0, USUALBOX
			beq t3, t2, USUALBOX
			j CONTINUEBOX
	CONTINUEBOX:
		la a1, box
		la a0, grid
		jal checkGrid
		beq a0, x0, DONEBOX
		j USUALBOX
	DONEBOX:
		li a3, 2
		la a0, grid
		mv a1, a2
		jal setGrid
#	j MainLoop
	la a2, target
	#Program the flag as two conditions:
	CHECKWHEREBOX:
		# a: Box on top/bottom row and left/right col:
		la t0, gridsize
		lb t1, 1(t0) #col num
		addi t1, t1, -1
		lb t2, (t0) #row num
		addi t2, t2, -1
		la t0, box
		lb t3, 1 (t0) #col num
		lb t4, (t0) #row num
		beq t3, x0, LCOL
		beq t3, t2, RCOL
		beq t4, x0, UROW
		beq t4, t1, DROW
		# b: center
		j USUALTARGET
	UROW:
		sb x0, (a2)
		la t0, gridsize
		lb t1, (t0)
		jal randcol
		la a1, target
		la a0, grid
		jal checkGrid
		beq a0, x0, DONETARGET
		j UROW
	DROW:
		la t0, gridsize
		lb t1, 1(t0)
		addi t1, t1, -1
		sb t1, (a2)
		lb t1, (t0)
		jal randcol
		la a1, target
		la a0, grid
		jal checkGrid
		beq a0, x0, DONETARGET
		j DROW
	LCOL:
		sb x0, 1(a2)
		la t0, gridsize
		lb t1, 1(t0)
		jal randrow
		la a1, target
		la a0, grid
		jal checkGrid
		beq a0, x0, DONETARGET
		j LCOL
	RCOL:
		la t0, gridsize
		lb t1, (t0)
		addi t1, t1, -1
		sb t1, 1(a2)
		lb t1, 1(t0)
		jal randrow
		la a1, target
		la a0, grid
		jal checkGrid
		beq a0, x0, DONETARGET
		j RCOL
	USUALTARGET:
		la t0, gridsize
		lb t1, (t0)
		lb t2, 1(t0)
		jal randpos
		la a1, target
		la a0, grid
		jal checkGrid
		beq a0, x0, DONETARGET
		j USUALTARGET
	DONETARGET:
		li a3, 3
		la a0, grid
		la a1, target
		jal setGrid
#Game loop
	la a0, grid
	la a1, gridsize
	jal saveGridState
	
	la a0, pNumUsers
	li a7, 4
	ecall
	# store num of players into numPlayers address.
	la a0, 1
	li a7, 5
	ecall
	#check if 0 or negative, doesn't make sense if so:
	LOOPFORCORRECTNUMBER:
	li t0, 1
	bge a0, t0, OK
	DEFAULT:
		li a0, 1
	OK:
	
	la a2, numPlayers
	sw a0, (a2)
	
	# Tell the new player its time to play.
	li a7, 4
	la a0, TimeFor
	ecall
	li a7, 1
	li a0, 1
	ecall
	li a7, 4
	la a0, ToPlay
	ecall
	j MainLoop
exit:
	
    li a7, 10
    ecall
    
    
# --- HELPER FUNCTIONS ---
# Feel free to use, modify, or add to them however you see fit.

# Main Game Loop

MainLoop:
	WHILE3:
		# ask for input (wasd)
		jal printGrid	
		#print grid.
		li a7, 4
		la a0, playInput
		ecall
		# for some reason, the input string get overwritten. So I must fix this ny doing the following
		li a7, 12
		ecall
		# check for validity
		la t0, w
		lb t1, (t0)
		beq t1, a0, MOVEUP
		la t0, a
		lb t1, (t0)
		beq t1, a0, MOVELEFT
		la t0, s
		lb t1, (t0)
		beq t1, a0, MOVEDOWN
		la t0, d
		lb t1, (t0)
		beq t1, a0, MOVERIGHT
		la t0, r
		lb t1, (t0)
		beq t1, a0, RESET
		la t0, hardR
		lb t1, (t0)
		beq t1, a0, HARDRESET
		la t0, c
		lb t1, (t0)
		beq t1, a0, CONCEED
		la t0, q
		lb t1, (t0)
		beq t1, a0, QUIT
	INV:
		li a7, 4
		la a0, invInput
		ecall
		j CHECK1
	MOVEUP:
		# add to replay
		li a0, 1
		jal AddToReplay
		# add a move
		la a1, move
		lw t0, (a1)
		addi t0, t0, 1
		sw t0, (a1)
		# Load the character, grid, and the movecode (trademark) into a0-2 for checkGridAhead
		la a1, character
		la a0, grid
		li a2, 0x1000
		jal checkGridAhead
		#Check for error codes
		li t0, 1
		beq t0, a0, CANTMOVE
		#Store result for later
		mv t6, a0
		# load 0 to set curr space to empty, and args for setGrid
		la a1, character
		la a0, grid
		jal getGrid
		jal LOADOBJPREV
		la a1, character
		la a0, grid
		jal setGrid
		# Decrement the row of the player.
		lb t0, 0(a1)
		addi t0, t0, -1
		sb t0, 0(a1)
		# load args to setGrid
		mv a0, t6
		jal LOADOBJ
		la a1, character
		la a0, grid
		jal setGrid
		j CHECK1
	MOVEDOWN:
		# add to replay
		li a0, 2
		jal AddToReplay
		# add a move
		la a1, move
		lw t0, (a1)
		addi t0, t0, 1
		sw t0, (a1)
		# Load the character, grid, and the movecode (trademark) into a0-2 for checkGridAhead
		la a1, character
		la a0, grid
		li a2, 0x0100
		jal checkGridAhead
		#Check for error codes
		li t0, 1
		beq t0, a0, CANTMOVE
		#Store result for later
		mv t6, a0
		# load 0 to set curr space to empty, and args for setGrid
		la a1, character
		la a0, grid
		jal getGrid
		jal LOADOBJPREV
		la a1, character
		la a0, grid
		jal setGrid
		# Decrement the row of the player.
		lb t0, 0(a1)
		addi t0, t0, 1
		sb t0, 0(a1)
		# load args to setGrid
		#Store result for later
		mv a0, t6
		jal LOADOBJ
		la a1, character
		la a0, grid
		jal setGrid
		j CHECK1
	MOVELEFT:
		# add to replay
		li a0, 3
		jal AddToReplay
		# add a move
		la a1, move
		lw t0, (a1)
		addi t0, t0, 1
		sw t0, (a1)
		# Load the character, grid, and the movecode (trademark) into a0-2 for checkGridAhead
		la a1, character
		la a0, grid
		li a2, 0x0010
		jal checkGridAhead
		#Check for error codes
		li t0, 1
		beq t0, a0, CANTMOVE
		#Store result for later
		mv t6, a0
		# load 0 to set curr space to empty, and args for setGrid
		la a1, character
		la a0, grid
		jal getGrid
		jal LOADOBJPREV
		la a1, character
		la a0, grid
		jal setGrid
		# Decrement the row of the player.
		lb t0, 1(a1)
		addi t0, t0, -1
		sb t0, 1(a1)
		# load args to setGrid
		mv a0, t6
		jal LOADOBJ
		la a1, character
		la a0, grid
		jal setGrid
		j CHECK1
	MOVERIGHT:
		# add to replay
		li a0, 4
		jal AddToReplay
		# add a move
		la a1, move
		lw t0, (a1)
		addi t0, t0, 1
		sw t0, (a1)
		# Load the character, grid, and the movecode (trademark) into a0-2 for checkGridAhead
		la a1, character
		la a0, grid
		li a2, 0x0001
		jal checkGridAhead
		#Check for error codes, box case
		li t0, 1
		beq t0, a0, CANTMOVE
		# If it is a box, we must move the box as well. We can simply treat it as a "player"
		# In the sense that it simply moves alongside the player, but cannot move into other
		# boxes:
		#Store result for later
		mv t6, a0
		# load a0 to set curr space to determined, and args for setGrid
		la a1, character
		la a0, grid
		jal getGrid
		jal LOADOBJPREV
		la a1, character
		la a0, grid
		jal setGrid
		# Decrement the row of the player.
		lb t0, 1(a1)
		addi t0, t0, 1
		sb t0, 1(a1)
		# load args to setGrid
		mv a0, t6
		jal LOADOBJ
		la a1, character
		la a0, grid
		jal setGrid
		j CHECK1
	CANTMOVE:
		li a7, 4
		la a0, cantMove
		ecall
		j CHECK1
	CHECK1:
		la a0, target
		lb t0, (a0)
		lb t1, 1(a0)
		la a0, box
		lb t2, (a0)
		lb t3, 1(a0)
		beq t0, t2, CHECK2
		j WHILE3
	CHECK2:
		
		beq t1, t3, WIN
		j WHILE3
	RESET:
		# add to replay
		li a0, 5
		jal AddToReplay
		# add a move
		la a1, move
		lw t0, (a1)
		addi t0, t0, 1
		sw t0, (a1)
		# Jump to start
		# j _start
		# Load the init gamestate.
		 la a0, grid
		 la a1, gridsize
		 jal loadGridState
		 j WHILE3
	QUIT:
		j exit
	HARDRESET:
		j _start
	CONCEED:
		# add a move.
		la a1, move
		lw t0, (a1)
		addi t0, t0, 1
		sw t0, (a1)
		# add to replay
		li a0, 6
		jal AddToReplay
		la a0, move
		lw t0, (a0)
		li t1, 0x80000000
		add t0, t0, t1
		sw t0, (a0)
		j PROCESSPLAYER
	WIN:
		jal printGrid
		li a7, 4
		la a0, winMSG1
		ecall
	PROCESSPLAYER:
		# store the score, player id into memory
		la t0, countPlayer
		lw a0, (t0)
		la t0, move
		lw a1, (t0)
		jal maskPlayer
		# check if move amount is odd, if so, then push the global counter by 1
		la t0, move
		lw a1, (t0)
		li t1, 1
		and t2, a1, t1
		li t1, 1
		bne t1, t2, CONT
		#odd
		la t0, globlShift
		lw a0, (t0)
		addi a0, a0, 1
		sw a0, (t0)
		# check if max players reached
		CONT:
		la t0, numPlayers
		lw t1, (t0)
		la t0, countPlayer
		lw t2, (t0)
		beq t1, t2, COMPLETE
		INCOMPLETE:
			# go to new player num
			addi t2, t2, 1
			sw t2, (t0)
			la t0, move
			mv t1, x0
			sw t1, (t0)
			# Tell the new player its time to play.
			li a7, 4
			la a0, TimeFor
			ecall
			li a7, 1
			mv a0, t2
			ecall
			li a7, 4
			la a0, ToPlay
			ecall
			li a0, 0 #just in case of bs.
			la a0, grid
			la a1, gridsize
			jal loadGridState
			j WHILE3
		COMPLETE:
			li a7, 4
			la a0, GameOver
			ecall
			jal printLeaderboard
			li a7, 4
			la a0, newline
			ecall
		ASKREPLAY:
			li a7, 4
			la a0, replayPrmpt
			ecall
			li a7, 12
			ecall
			la t0, n
			lb t1, (t0)
			beq t1, a0, EXITGAME
			li a7, 4
			la a0, replayNum
			ecall
			li a7, 5
			ecall
			li t0, 1
			blt a0, t0, INVREPLAY
			la t0, numPlayers
			lw t0, (t0)
			addi t0, t0, 1
			bge a0, t0, INVREPLAY
			mv t0, a0
			j REPLAY
		INVREPLAY:
			li a7, 4
			la a0, invReplay
			ecall
			j ASKREPLAY
		REPLAY:
			li a7, 4
			la a0, strtReplay
			ecall
			li a7, 1
			mv a0, t0
			ecall
			la a0, newline
			li a7, 4
			ecall
			mv a0, t0
			jal watchReplay
			j ASKREPLAY
		EXITGAME:
			li a7, 4
			la a0, promptUSER
			ecall
			li a7, 12
			ecall
			la t0, n
			lb t1, (t0)
			beq t1, a0, QUIT
			j _start
	


# Redundancy function. Loads grid dim into t1, t2, inits grid to be empty.
initGrid:
	la t0, gridsize
	lb t1, (t0)
	lb t2, 1(t0)
	la t0, grid
	LOOPINITiG:
	    #USING T6 as stopping, t3 as loop variant, t4 as empty space
		mul t6, t1, t2
		li t3, 0
		li t4, 0
		# Load grid into t0
		la t0, grid
	WHILEiG:
		# Check stopping condition.
		beq t6, t3, DONEiG
		# store empty space into grid:
		sb t4, 0(t0)
		addi t0, t0, 1
		addi t3, t3, 1
		j WHILEiG
	DONEiG:
		jr ra

# Arguments: an address in a0 (grid), a1(object)
# Return: 1 if there is something in a0, else 0. Return 2 for erratum
checkGrid:
	# load object coords, grid starting coords.
	la t0, gridsize
	lb t1, (t0)
	lb t2, 1(t0)
	# only need row, so t2 is useless.
	# x, y coords
	lb t2, 0(a1)
	lb t3, 1(a1)
	mul t4, t1, t2 #mult rows
	add t4, t4, t3 #add col
	add a0, a0, t4 #offset to the address.
	# load object at a0 + offset, 0
	lb t2, (a0)
	li t3, 0
	IFcG:
		bne t2, t3, THENcG
		li a0, 0
		jr ra
	THENcG:
		li a0, 1
		jr ra
	li a0, 2
	jr ra


# Arguments: an address in a0 (grid), a1(object), a2(dir) (masked)
# Return: 1 if there is something in a0, else 0. Return 2 for player to target, 3 for box in front.
checkGridAhead:
	# load object coords, grid size.
	la t0, gridsize
	lb t1, (t0)
	lb t6, 1(t0)
	# x, y coords
	lb t2, (a1)
	lb t3, 1(a1)
	mul t4, t1, t2 #mult rows
	add t4, t4, t3 #add col
	add a0, a0, t4 #offset to the address.
	# Check the dir vector (bitmasked such that w = 1000, a = 0010, s = (0100), and d = (0001)
	li t4, 0x1111
	li t5, 1
	and t4, t4, a2 #gets one of the directed vectors
	IFcGA:
		beq t4, t5, DcGA
		srli t4, t4, 4
		beq t4, t5, AcGA
		srli t4, t4, 4
		beq t4, t5, ScGA
		srli t4, t4, 4
		beq t4, t5, WcGA
		DcGA: 
			addi t3, t3, 1
			bge t3, t1, THENcGA #OOB
			addi a0, a0, 1
			# Checks if equal to target
			li t5, 3
			lb t4, (a0)
			beq t5, t4, TARGETcGA #For now, ignore boxes.
			# Check if equal to box
			li t5, 2
			lb t4, (a0)
			beq t5, t4, BOXcGA #Boxes are special.
			#Check if target
			li a0, 0
			jr ra
		AcGA: 
			addi t3, t3, -1
			blt t3, x0, THENcGA #OOB
			addi a0, a0, -1
			# Checks if equal to target
			li t5, 3
			lb t4, (a0)
			beq t5, t4, TARGETcGA #For now, ignore boxes.
			# Check if equal to box
			li t5, 2
			lb t4, (a0)
			beq t5, t4, BOXcGA #Boxes are special.
			#Check if target
			li a0, 0
			jr ra
		ScGA: 
			addi t2, t2, 1
			bge t2, t6,THENcGA #OOB
			li t6, 1
			mul t6, t1, t6
			add a0, a0, t6 #Offset correctly for one row above.
			# Checks if equal to target
			li t5, 3
			lb t4, (a0)
			beq t5, t4, TARGETcGA #For now, ignore boxes.
			# Check if equal to box
			li t5, 2
			lb t4, (a0)
			beq t5, t4, BOXcGA #Boxes are special.
			#Check if target
			li a0, 0
			jr ra
		WcGA: 
			addi t2, t2, -1
			blt t2, x0,THENcGA #OOB
			li t6, -1
			mul t6, t1, t6
			add a0, a0, t6 #Offset correctly for one row above.
			# Checks if equal to target
			li t5, 3
			lb t4, (a0)
			beq t5, t4, TARGETcGA #For now, ignore boxes.
			# Check if equal to box
			li t5, 2
			lb t4, (a0)
			beq t5, t4, BOXcGA #Boxes are special.
			#Check if target
			li a0, 0
			jr ra
	# load object at a0 + offset, 0
	#lb t2, (a0)
#	li t3, 0
#	IFcG:
#		bne t2, t3, THENcG
#		li a0, 0
#		jr ra
	TARGETcGA:
		li a0, 3
		jr ra
	BOXcGA:
		la a0, grid
		la a1, box
		mv a6, ra
		jal checkGridAheadB
		# Store for later :)
		li t0, 1
		beq t0, a0, THENcGA2
		mv t6, a0
		# load a0 to set curr space to determined, and args for setGrid
		la a1, box
		la a0, grid
		jal getGrid
		jal LOADOBJPREVB
		la a1, box
		la a0, grid
		jal setGrid
		# load args to setGrid
		mv a0, t6
		jal LOADOBJB
		la a1, box
		la a0, grid
		jal setGrid
		li a0, 0
		mv ra, a6
		jr ra
	THENcGA:
		li a0, 1
		jr ra
	THENcGA2:
		mv ra, a6
		li a0, 1
		jr ra
	li a0, 4
	jr ra

# Arguments: an address in a0 (grid), a1(object), a3(number)
setGrid:
	# load object coords, grid starting coords.
	la t0, gridsize
	lb t1, (t0)
	lb t2, 1(t0)
	# only need row, so t2 is useless.
	# x, y coords
	lb t2, 0(a1)
	lb t3, 1(a1)
	mul t4, t1, t2 #mult rows
	add t4, t4, t3 #add col
	add a0, a0, t4 #offset to the address.
	sb a3, 0(a0)
	jr ra
# Arguments: an address in a0 (grid), a1(object)	
# Returns: The objcode at the grid of the object (a0)
getGrid:
	# load object coords, grid starting coords.
	la t0, gridsize
	lb t1, (t0)
	lb t2, 1(t0)
	# only need row, so t2 is useless.
	# x, y coords
	lb t2, 0(a1)
	lb t3, 1(a1)
	mul t4, t1, t2 #mult rows
	add t4, t4, t3 #add col
	add a0, a0, t4 #offset to the address.
	lb a0, (a0)
	jr ra
	
# No arguments, just print the grid.
printGrid:
	la t0, gridsize
	lb t1, (t0) # col num
	lb t2, 1(t0) # row num
	li t3, 0xff
	and t1, t1, t3
	and t2, t2, t3
	#Newline clear
	la a0, newline
	li a7, 4
	ecall
	printTopBorder:
		mv t6, t1
		addi t6, t6, 2
		li t3, 0
		loop3:
			beq t6, t3, LOOPINITpG
			addi t3, t3, 1
			la a0, wallStr
			li a7, 4
			ecall
			j loop3
			
	
	LOOPINITpG:
		la a0, newline
		li a7, 4
		ecall
	    #USING T6 as stopping, t3 as loop variant
		mul t6, t1, t2
		li t3, 0
		li t5, 0
		# Load grid into t0
		la t0, grid
	WHILEpG:
		bne t5, x0, skipWall
		la a0, wallStr
		li a7, 4
		ecall
		skipWall:
		beq t6, t3, DONEpG
		addi t3, t3, 1
		addi t5, t5, 1
		# chain checking for what character.
		li t4, 0
		lb a0, 0(t0)
		beq a0,t4,print0
		addi t4, t4, 1
		beq a0,t4,print1
		addi t4,t4,1
		beq a0,t4,print2
		addi t4,t4,1
		beq a0,t4,print3
		addi t4,t4,1
		beq a0,t4,print3
		addi t4,t4,1
		beq a0,t4,print5
		addi t4,t4,1
		beq a0,t4,print6
		# Check stopping condition.
		
		# store empty space into grid:
		j WHILEpG
		print0:
			la a0, emptySpStr
			li a7, 4
			ecall
			addi t0, t0, 1
			#check for after n rows
			beq t5, t1, printNewline
			j WHILEpG
		print1:
			la a0, charStr
			li a7, 4
			ecall
			addi t0, t0, 1
			#check for after n rows
			beq t5, t1, printNewline
			j WHILEpG
		print2:
			la a0, boxStr
			li a7, 4
			ecall
			addi t0, t0, 1
			#check for after n rows
			beq t5, t1, printNewline
			j WHILEpG
		print3:
			la a0, targetStr
			li a7, 4
			ecall
			addi t0, t0, 1
			#check for after n rows
			beq t5, t1, printNewline
			j WHILEpG
		print5:
			la a0, tarBoxStr
			li a7, 4
			ecall
			addi t0, t0, 1
			#check for after n rows
			beq t5, t1, printNewline
			j WHILEpG
		print6:
			la a0, tarCharStr
			li a7, 4
			ecall
			addi t0, t0, 1
			#check for after n rows
			beq t5, t1, printNewline
			j WHILEpG
		printNewline:
			la a0, wallStr
			li a7, 4
			ecall
			la a0, newline
			li a7, 4
			ecall
			sub t5,t5,t1
			j WHILEpG
	DONEpG:
		printBottomBorder:
		la t0, gridsize
		lb t1, (t0) # col num
		lb t2, 1(t0) # row num
		li t3, 0xff
		and t1, t1, t3
		and t2, t2, t3
		mv t6, t1
		addi t6, t6, 1
		li t3, 0
		loop5:
			beq t6, t3, done
			addi t3, t3, 1
			la a0, wallStr
			li a7, 4
			ecall
			j loop5
		done:
		la a0, newline
		li a7, 4
		ecall
		jr ra

# arguments: a0: object # input
# returns: a3: associated object output code
LOADOBJ:
	li t0, 3
	beq t0, a0, LOADTARGET1
	li t0, 0
	beq t0, a0, LOADEMPTY1
	LOADTARGET1:
		li a3, 6
		jr ra
	LOADEMPTY1:
		li a3, 1
		jr ra
# arguments: a0: object # input
# returns: a3: associated object output code
LOADOBJB:
	li t0, 3
	beq t0, a0, LOADTARGET3
	li t0, 0
	beq t0, a0, LOADEMPTY3
	LOADTARGET3:
		li a3, 5
		jr ra
	LOADEMPTY3:
		li a3, 2
		jr ra

# arguments: a0: object # input
# returns: a3: associated object output code
LOADOBJPREV:
	li t0, 6
	beq t0, a0, LOADTARGET2
	li t0, 1
	beq t0, a0, LOADEMPTY2
	LOADTARGET2:
		li a3, 3
		jr ra
	LOADEMPTY2:
		li a3, 0
		jr ra

LOADOBJPREVB:
	li t0, 5
	beq t0, a0, LOADTARGET4
	li t0, 0
	beq t0, a0, LOADEMPTY4
	li t0, 3
	beq t0, a0, LOADCOMPLETE4
	LOADTARGET4:
		li a3, 3
		jr ra
	LOADEMPTY4:
		li a3, 0
		jr ra
	LOADCOMPLETE4:
		li a3, 3
		jr ra
# Arguments: an address in a0 (grid), a1(object), a2(dir) (masked)
# Return: 1 if there is something in a0, else 0. Return 2 for player to target, 3 for box in front.

checkGridAheadB:
	# load object coords, grid size.
	la t0, gridsize
	lb t1, (t0)
	lb t6, 1(t0)
	# only need row, so t2 is useless.
	# x, y coords
	lb t2, 0(a1)
	lb t3, 1(a1)
	mul t4, t1, t2 #mult rows
	add t4, t4, t3 #add col
	add a0, a0, t4 #offset to the address.
	# Check the dir vector (bitmasked such that w = 1000, a = 0010, s = (0100), and d = (0001)
	li t4, 0x1111
	li t5, 1
	and t4, t4, a2 #gets one of the directed vectors
	IFcGAB:
		beq t4, t5, DcGAB
		srli t4, t4, 4
		beq t4, t5, AcGAB
		srli t4, t4, 4
		beq t4, t5, ScGAB
		srli t4, t4, 4
		beq t4, t5, WcGAB
		DcGAB: 
			addi t3, t3, 1
			bge t3, t1, THENcGAB #OOB
			addi a0, a0, 1
			# Checks if equal to target
			li t5, 3
			lb t4, (a0)
			beq t5, t4, TARGETDcGAB #For now, ignore boxes.
			# Check if equal to box
			li t5, 0
			lb t4, (a0)
			bne t5, t4, THENcGAB #For now, ignore boxes.
			#Check if target
			li a0, 0
			# Decrement the column of the box.
			lb t0, 1(a1)
			addi t0, t0, 1
			sb t0, 1(a1)
			jr ra
		AcGAB: 
			addi t3, t3, -1
			blt t3, x0, THENcGAB #OOB
			addi a0, a0, -1
			# Checks if equal to target
			li t5, 3
			lb t4, (a0)
			beq t5, t4, TARGETAcGAB #For now, ignore boxes.
			# Check if equal to box
			li t5, 0
			lb t4, (a0)
			bne t5, t4, THENcGAB #For now, ignore boxes.
			#Check if target
			li a0, 0
			# Decrement the column of the box.
			lb t0, 1(a1)
			addi t0, t0, -1
			sb t0, 1(a1)
			jr ra
		ScGAB: 
			addi t2, t2, 1
			bge t2, t6,THENcGAB #OOB
			li t6, 1
			mul t6, t1, t6
			add a0, a0, t6 #Offset correctly for one row above.
			# Checks if equal to target
			li t5, 3
			lb t4, (a0)
			beq t5, t4, TARGETScGAB #For now, ignore boxes.
			# Check if equal to box
			li t5, 0
			lb t4, (a0)
			bne t5, t4, THENcGAB #For now, ignore boxes.
			#Check if target
			li a0, 0
			lb t0, 0(a1)
			addi t0, t0, 1
			sb t0, 0(a1)
			jr ra
		WcGAB: 
			addi t2, t2, -1
			blt t2, x0,THENcGAB #OOB
			li t6, -1
			mul t6, t1, t6
			add a0, a0, t6 #Offset correctly for one row above.
			# Checks if equal to target
			li t5, 3
			lb t4, (a0)
			beq t5, t4, TARGETWcGAB #For now, ignore boxes.
			# Check if equal to box
			li t5, 0
			lb t4, (a0)
			bne t5, t4, THENcGAB #For now, ignore boxes.
			#Check if target
			li a0, 0
			lb t0, 0(a1)
			addi t0, t0, -1
			sb t0, 0(a1)
			jr ra
	# load object at a0 + offset, 0
	#lb t2, (a0)
#	li t3, 0
#	IFcG:
#		bne t2, t3, THENcG
#		li a0, 0
#		jr ra
	TARGETWcGAB:
		li a0, 3
		lb t0, 0(a1)
		addi t0, t0, -1
		sb t0, 0(a1)
		jr ra
	TARGETAcGAB:
		li a0, 3
		lb t0, 1(a1)
		addi t0, t0, -1
		sb t0, 1(a1)
		jr ra
	TARGETScGAB:
		li a0, 3
		lb t0, 0(a1)
		addi t0, t0, 1
		sb t0, 0(a1)
		jr ra
	TARGETDcGAB:
		li a0, 3
		lb t0, 1(a1)
		addi t0, t0, 1
		sb t0, 1(a1)
		jr ra
	THENcGAB:
		li a0, 1
		jr ra
	li a0, 4
	jr ra

# a0: address of the seed
# Returns nothing.
seed_gen:
	mv a6, ra
	li a0, 14232
	jal notrand
	la t0, seed
	sw a0, (t0)
	jr a6

# =============================================
# Psuedorandomness: LCG (line  1251 - line 1265)
# 
# Citation: Derrick Henry Lehmer. Linear Congruential Generator. 
# Retrieved October 10, 2024 from https://en.wikipedia.org/wiki/Linear_congruential_generator
# =============================================

# a0: seed via notrand, a1: max val (ex.)
# a0: rng mod a1.
lcg:
    li t1, 2017963
	li t2, 584141
	li t3, 0xefffffff
	# lcg
	mul a0, a0, t1
	add a0, a0, t2
	rem a0, a0, t3
	# mod to get to appropriate amount
	rem a0, a0, a1
	li t4, -1
	mv t5, ra
	jal abs
	mv ra, t5
	jr ra

# a0: integer input
# a0: absolute value of integer.
abs:
	blt a0, x0, NEG
	POS:
		jr ra
	NEG:
		li t0, -1
		mul a0, a0, t0
		jr ra

# Arguments: an integer MAX in a0
# Return: A number from 0 (inclusive) to MAX (exclusive)
notrand:
    mv t0, a0
    li a7, 30
    ecall             # time syscall (returns milliseconds)
    remu a0, a0, t0   # modulus on bottom bits 
#    li a7, 32
#    ecall             # sleeping to try to generate a different number
    jr ra

# Arguments: an address in a2, an integer MAX in t1, t2
# Return: Nothing, serves only to randgen nums.
randpos:
    # save the ra address upon func call.
	mv a5, ra
	jal seed_gen
	mv a1, t1
	mv a4, t2
	la a0, seed
	lw a0, (a0)
    jal lcg
	sb a0, 1(a2) # (switch if needed.)
	jal seed_gen
	la a0, seed
	lw a0, (a0)
	mv a1, a4
    jal lcg
	sb a0, (a2) # (switch if needed.)
	jr a5
# Arguments: an address in a2, an integer MAX in t1
# Return: Nothing, serves only to randgen nums.
randcol:
	mv a5, ra
	jal seed_gen
	mv a1, t1
	mv a4, t2
	la a0, seed
	lw a0, (a0)
    jal lcg
	sb a0, 1(a2)
	jr a5
# Arguments: an address in a2, an integer MAX in t2
# Return: Nothing, serves only to randgen nums.
randrow:
	mv a5, ra
	jal seed_gen
	mv a1, t1
	mv a4, t2
	la a0, seed
	lw a0, (a0)
    jal lcg
	sb a0, (a2)
	jr a5
	

# ENHANCEMENT 1. MULTIPLAYER.
# =====================================
# a0 - grid address
# a1 - grid size

# no return
saveGridState:
	INITLOOPsGS:
		lb t0, (a1)
		lb t1, 1(a1)
		# t6 is stopping.
		mul t6, t1,t0
		# counters.
		li t3, 0
		li t5, 0
		#address to store the grid
		li a2, 0x10000000
	WHILEsGS:
		# indices
		# adding offset
		lb t4, (a0)
		sb t4, (a2)
		addi a2, a2, 1
		addi a0, a0, 1
		# checking increment
		addi t3, t3, 1
		bne t3, t6, WHILEsGS
	DONEsGS:
		# save the player, box, target positions:
		la t0, character
		lb t1, (t0)
		lb t2, 1(t0)
		sb t1, (a2)
		addi a2, a2, 1
		sb t2, (a2)
		addi a2, a2, 1
		
		la t0, box
		lb t1, (t0)
		lb t2, 1(t0)
		sb t1, (a2)
		addi a2, a2, 1
		sb t2, (a2)
		addi a2, a2, 1
		
		la t0, target
		lb t1, (t0)
		lb t2, 1(t0)
		sb t1, (a2)
		addi a2, a2, 1
		sb t2, (a2)
		addi a2, a2, 1
		
		jr ra
# a0 - grid address
# a1 - grid size	
loadGridState:
	INITLOOPlGS:
		lb t0, (a1)
		lb t1, 1(a1)
		# t6 is stopping.
		mul t6, t1,t0
		# counters.
		li t3, 0
		li t5, 0
		#address to store the grid
		li a2, 0x10000000
	WHILElGS:
		# adding offset
		lb t4, (a2)
		sb t4, (a0)
		addi a2, a2, 1
		addi a0, a0, 1
		# checking increment
		addi t3, t3, 1
		bne t3, t6, WHILElGS
	DONElGS:
	# Load char, box, player.
		la t0, character
		lb t1, (a2)
		addi a2, a2, 1
		lb t2, (a2)
		addi a2, a2, 1
		sb t1, (t0)
		sb t2, 1(t0)
		
		
		la t0, box
		lb t1, (a2)
		addi a2, a2, 1
		lb t2, (a2)
		addi a2, a2, 1
		sb t1, (t0)
		sb t2, 1(t0)
		
		la t0, target
		lb t1, (a2)
		addi a2, a2, 1
		lb t2, (a2)
		addi a2, a2, 1
		sb t1, (t0)
		sb t2, 1(t0)
		jr ra

# a0, player id
# a1, move count
maskPlayer:
	# there are two heaps: one at x20000000, one at x50000000,
	# where x2 is to store the id of the player, x4 is to store the score of the player
	li a3, 0x20000000
	li a4, 0x50000000
	INITLOOPmP:
		mv t0, a3
		addi t0, t0, -4
		mv t1, a4
		addi t1, t1, -4
		add t2, a3, a4 #max
		li t3, 0xaaaaaaaa
	WHILEmP:
		addi t0, t0, 4
		addi t1, t1, 4
		lw t4, (t0)
		bne t4, t3, CHECKSCOREmP# default value at these codes; if not default,
		# then there is a player to check against. otherwise just store as usual.
		sw a0, 0(t0)
		sw a1, 0(t1)
		j DONEmP
	CHECKSCOREmP:
		lw t4, (t1)
		# postive moves = positive in stack
		beq t4, a1, WHILEmP
		# negative moves
		blt a1, x0, WHILEmP
		# positive moves, get out negative
		blt t4, x0, pushDown
		# postive moves < positive in stack
		bge t4, a1, pushDown
		j WHILEmP
	pushDown:
		lw t4, (t0) # store player id
		lw t5, (t1) # store player moves
		sw a0, (t0)
		sw a1, (t1)
		mv a0, t4 # move to push down the players.
		mv a1, t5 # move to push down the players.
		addi t0, t0, 4
		addi t1, t1, 4
		lw t4, (t0)
		bne t4, t3, pushDown
		# Once we are past then it means that there is an empty entry.
		sw a0, (t0)
		sw a1, (t1)
		j DONEmP
	DONEmP:
		jr ra

		
# no inputs, only output
printLeaderboard:
	# there are two heaps: one at x20000000, one at x50000000,
	# where x2 is to store the id of the player, x4 is to store the score of the player
	li a3, 0x20000000
	li a4, 0x50000000
	# simply going down the heap is enough; pushDown guarentees sorted.
	LOOPINITpL:
		li t6, 0 #prep offset.
		li t0, 4 #prep memory offset.
		# print leaderboard
		la a0, leaderboard
		li a7, 4
		ecall
	WHILEpL:
		
		
		lw t1, (a3)
		
		lw t2, (a4)
		# print number + player number + moves.
		addi t6, t6, 1
		mv a0, t6
		li a7, 1
		ecall
		addi t6, t6, -1
		
		la a0, playernum
		li a7, 4
		ecall
		mv a0, t1
		li a7, 1
		ecall
		
		la a0, colon
		li a7, 4
		ecall
		bge t2, x0, REG
		#DNF
		li a7, 4
		la a0, DNF
		ecall
		j CONTINUATION
		REG:
		mv a0, t2
		li a7, 1
		ecall
		
		la a0, nummoves
		li a7, 4
		ecall
		
		CONTINUATION:
		#increment counter
		addi t6, t6, 1
		add a3, a3, t0
		add a4, a4, t0
		# check stopping con.
		la t5, numPlayers
		lw t5, (t5)
		beq t5, t6, DONE
		j WHILEpL
	DONE:
		jr ra
		
clearLeaderboard:
	li a3, 0x20000000
	li a4, 0x50000000
	li a5, 0x80000000
	# simply going down the heap is enough; pushDown guarentees sorted.
	LOOPINITcL1:
	#init clearing of leaderboards
		mv t6, a3
		li t5, 0xaaaaaaaa #default val
	WHILEcL1:
		#clear player ids.
		sw t5, (t6)
		addi t6, t6, 4
		lw t4, (t6)
		beq t4, t5, LOOPINITcL2
		j WHILEcL1
	LOOPINITcL2:
	#init clearing of leaderboards
		mv t6, a4
	WHILEcL2:
	#clear moves.
		sw t5, (t6)
		addi t6, t6, 4
		lw t4, (t6)
		beq t4, t5, DONEcL
		j WHILEcL1
	DONEcL:
		jr ra
	
clearGridMemory:
	li a3, 0x10000000
	LOOPINITcGM:
	#init clearing of leaderboards
		mv t6, a3
		li t5, 0xaaaaaaaa #default val
	WHILEcGM:
		#clear player ids.
		sw t5, (t6)
		addi t6, t6, 4
		lw t4, (t6)
		beq t4, t5, DONEcGM
		j WHILEcGM
	DONEcGM:
		jr ra
		
# ENHANCEMENT 2. REPLAY
# =====================================	
# Hey, this is where bitmasking the movement is actually useful:
# Since movement is encoded such that W = 1000, S = 0100, A = 0010, D = 0001,
# just slli and add 1,2,4 or 8 until desired. Since we also know their move counts, it is easy to track the number of moves.
# All replay is stored at 0x60000000

# Clears replay heap.
ClearReplay:
	li a3, 0x80000000
	LOOPINITcR:
	#init clearing of replay
		mv t6, a3
		li t5, 0xaaaaaaaa #default val
	WHILEcR:
		#clear player ids.
		sw t5, (t6)
		addi t6, t6, 4
		lw t4, (t6)
		beq t4, t5, DONEcGM
		j WHILEcGM
	DONEcR:
		jr ra

# a0: move code
AddToReplay:
	li a2, 0x80000000
	la t0, globlShift
	lw t1, (t0)
	add a2, a2, t1
	lb t1, (a2)
	li t4, 0xf
	and t2, t1, t4
	li t4, 0xa
	beq t4,t2,OVERRIDEUNIT
	# Override the tens place.
	and t3, t3, x0
	mv t3, a0
	slli t3, t3, 4
	add t3,t3,t2
	# Add to globlShift only after incrementing the tens place.
	lw t1, (t0)
	addi t1, t1, 1
	sw t1, (t0)
	j AFTER
	OVERRIDEUNIT:
		and t3, t3, x0
		add t3, t3, a0
	AFTER:
		sb t3, (a2)
		jr ra


# To avoid random memory misalignment, 0 is a buffer.
# a0: Player number

# a1: The number of moves that previous players did combined (as offset).
# a2: The number of moves that the curr id player did.
findAllMovesAddress:
	li a3, 0x20000000 #player id
	li a4, 0x50000000 #moves
	LOOPINTfAMA:
		li t0, 0#tracker
		li t6, 0xaaaaaaaa #stopping point
	WHILEfAMA:
		# load player id, moves
		lw t1, (a3)
		lw t2, (a4)
		# increment
		addi a3, a3, 4
		addi a4, a4, 4
		# check if it is a spam
		beq t6, t1, ENDLOOPfAMA
		# check for same player
		beq a0, t1, MOVESET
		# check player id not greater than or equal to curr id.
		bge t1, a0, WHILEfAMA
	ADDTOTRACKER:
		# CONVERT TO NONNEG 
		blt t2, x0, NONEGATIVE
		j SKIPNONEGATIVE
		NONEGATIVE:
			li t1, 0x80000000
			sub t2, t2, t1
		SKIPNONEGATIVE:
		# check divisibility by 2
		li t3, 1
		and t4, t2, t3
		bne t4, x0, ODDfAMA
		# div by 2 (store more info if we compress two moves into 1 byte)
		li t3, 2
		div t4, t2, t3 
		add t0, t0, t4
		j WHILEfAMA
		ODDfAMA:
			addi t2, t2,1
			li t3, 2
			div t4, t2, t3
			add t0, t0, t4
			j WHILEfAMA
	MOVESET:
		blt t2, x0, NONEG
		j SKIPNONEG
		NONEG:
			li t1, 0x80000000
			sub t2, t2, t1
		SKIPNONEG:
		mv a2, t2
		j WHILEfAMA
	ENDLOOPfAMA:
		mv a1, t0
		jr ra
# a0: Player number.
watchReplay:
	mv a6, ra
	mv a5, a0
	la a0, grid
	la a1, gridsize
	jal loadGridState
	mv a0, a5
	jal findAllMovesAddress
	blt a2, x0, DNFwR
	j OVERwR
	DNFwR:
		li a5, 0x80000000
		sub a2, a2, a5
	OVERwR:
		mv ra, a6
		li a5, 0x80000000
		add a5, a5, a1
	INITLOOPwR:
		addi sp, sp, -4
		sw ra, (sp) # store ra beforehand
		li t1, 1
		and t2, a2, t1
		li t1, 2
		beq t2, x0, EVENITY
		ODDITY:
			addi a2, a2, 1
			div t1, a2, t1 #endpoint
			j DONITY
		EVENITY:
			div t1, a2, t1 #endpoint
			j DONITY
		DONITY:
		addi sp, sp, -4
		sw t1, (sp)
		mv t0, x0 #counter
		addi sp, sp, -4
		sw t0, (sp)
		addi sp, sp, -4
		sw a5, (sp)
		addi sp, sp, -4
	WHILEwR:
		# 1 - W
		# 2 - S
		# 3 - A
		# 4 - D
		# 5 - R
		addi sp, sp, 4
		lw a5, (sp)
		addi sp, sp, 4
		lw t0, (sp)
		add t2, a5, t0
		lb t3, (t2)
		addi t4, x0, 0xf
		and t5, t4, t3
		addi t4, x0, 0xf0
		and t6, t4, t3
		srli t6, t6, 4
		sw t0, (sp)
		addi sp, sp, -8
		sw t6, (sp)
		addi sp, sp, -4
		mv a2, t5
		# 1 second break
		jal ReplayLoop
		li a7, 32
		li a0, 1000
		ecall
		addi sp, sp, 4
		lw t6, (sp)
		mv a2, t6
		# 1 second break
		jal ReplayLoop
		li a7, 32
		li a0, 1000
		ecall
		addi sp, sp, 8
		lw t0, (sp)
		addi sp, sp, 4
		lw t1, (sp)
		addi t0, t0,1
		sw t1, (sp)
		addi sp, sp, -4
		sw t0, (sp)
		addi sp, sp, -8
		blt t0, t1, WHILEwR
	DONEwR:
		addi sp, sp, 16
		lw ra, (sp)
		addi sp, sp, 4
		jr ra

# i love copying and pasting.
# a2: input of a character/move code.
ReplayLoop:
	sw ra, (sp)
	addi sp, sp, -4
	BEGINRL:
		# ask for input (wasd)
		DETERMINERL:
			li t0, 1
			beq a2, t0, WRL
			li t0, 2
			beq a2, t0, SRL
			li t0, 3
			beq a2, t0, ARL
			li t0, 4
			beq a2, t0, DRL
			li t0, 5
			beq a2, t0, RRL
			li t0, 6
			beq a2, t0, CRL
			# if line below executes, then its 0 (buffer).
			addi sp, sp, 4
			lw ra, (sp)
			jr ra
		WRL:
			la a2, w
			li a3, 1
			j DONERL
		SRL:
			la a2, s
			li a3, 2
			j DONERL
		ARL:
			la a2, a
			li a3, 3
			j DONERL
		DRL:
			la a2, d
			li a3, 4
			j DONERL
		RRL:
			la a2, r
			li a3, 5
			j DONERL
		CRL:
			la a2, c
			li a3, 6
			j DONERL
		DONERL:
		jal printGrid	
		#print grid.
		li a7, 4
		la a0, playInput
		ecall
		# for some reason, the input string get overwritten. So I must fix this ny doing the following
		li a7, 4
		mv a0, a2
		ecall
		la a0, newline
		li a7, 4
		ecall
		mv a0, a3
		# check for validity
		li t1, 1
		beq t1, a0, MOVEUPRL
		li t1, 2
		beq t1, a0, MOVEDOWNRL
		li t1, 3
		beq t1, a0, MOVELEFTRL
		li t1, 4
		beq t1, a0, MOVERIGHTRL
		li t1, 5
		beq t1, a0, RESETRL
		li t1, 6
		beq t1, a0, CONCEEDRL
#		la t0, q
#		lb t1, (t0)
#		beq t1, a0, QUIT
	MOVEUPRL:
		# add a move
		la a1, move
		lw t0, (a1)
		addi t0, t0, 1
		sw t0, (a1)
		# Load the character, grid, and the movecode (trademark) into a0-2 for checkGridAhead
		la a1, character
		la a0, grid
		li a2, 0x1000
		jal checkGridAhead
		#Check for error codes
		li t0, 1
		beq t0, a0, CANTMOVERL
		#Store result for later
		mv t6, a0
		# load 0 to set curr space to empty, and args for setGrid
		la a1, character
		la a0, grid
		jal getGrid
		jal LOADOBJPREV
		la a1, character
		la a0, grid
		jal setGrid
		# Decrement the row of the player.
		lb t0, 0(a1)
		addi t0, t0, -1
		sb t0, 0(a1)
		# load args to setGrid
		mv a0, t6
		jal LOADOBJ
		la a1, character
		la a0, grid
		jal setGrid
		j CHECK1RL
	MOVEDOWNRL:
		# add a move
		la a1, move
		lw t0, (a1)
		addi t0, t0, 1
		sw t0, (a1)
		# Load the character, grid, and the movecode (trademark) into a0-2 for checkGridAhead
		la a1, character
		la a0, grid
		li a2, 0x0100
		jal checkGridAhead
		#Check for error codes
		li t0, 1
		beq t0, a0, CANTMOVERL
		#Store result for later
		mv t6, a0
		# load 0 to set curr space to empty, and args for setGrid
		la a1, character
		la a0, grid
		jal getGrid
		jal LOADOBJPREV
		la a1, character
		la a0, grid
		jal setGrid
		# Decrement the row of the player.
		lb t0, 0(a1)
		addi t0, t0, 1
		sb t0, 0(a1)
		# load args to setGrid
		#Store result for later
		mv a0, t6
		jal LOADOBJ
		la a1, character
		la a0, grid
		jal setGrid
		j CHECK1RL
	MOVELEFTRL:
		# add a move
		la a1, move
		lw t0, (a1)
		addi t0, t0, 1
		sw t0, (a1)
		# Load the character, grid, and the movecode (trademark) into a0-2 for checkGridAhead
		la a1, character
		la a0, grid
		li a2, 0x0010
		jal checkGridAhead
		#Check for error codes
		li t0, 1
		beq t0, a0, CANTMOVERL
		#Store result for later
		mv t6, a0
		# load 0 to set curr space to empty, and args for setGrid
		la a1, character
		la a0, grid
		jal getGrid
		jal LOADOBJPREV
		la a1, character
		la a0, grid
		jal setGrid
		# Decrement the row of the player.
		lb t0, 1(a1)
		addi t0, t0, -1
		sb t0, 1(a1)
		# load args to setGrid
		mv a0, t6
		jal LOADOBJ
		la a1, character
		la a0, grid
		jal setGrid
		j CHECK1RL
	MOVERIGHTRL:
		# Load the character, grid, and the movecode (trademark) into a0-2 for checkGridAhead
		la a1, character
		la a0, grid
		li a2, 0x0001
		jal checkGridAhead
		#Check for error codes, box case
		li t0, 1
		beq t0, a0, CANTMOVERL
		# If it is a box, we must move the box as well. We can simply treat it as a "player"
		# In the sense that it simply moves alongside the player, but cannot move into other
		# boxes:
		#Store result for later
		mv t6, a0
		# load a0 to set curr space to determined, and args for setGrid
		la a1, character
		la a0, grid
		jal getGrid
		jal LOADOBJPREV
		la a1, character
		la a0, grid
		jal setGrid
		# Decrement the row of the player.
		lb t0, 1(a1)
		addi t0, t0, 1
		sb t0, 1(a1)
		# load args to setGrid
		mv a0, t6
		jal LOADOBJ
		la a1, character
		la a0, grid
		jal setGrid
		j CHECK1RL
	CANTMOVERL:
		li a7, 4
		la a0, cantMove
		ecall
		j CHECK1RL
	CHECK1RL:
		la a0, target
		lb t0, (a0)
		lb t1, 1(a0)
		la a0, box
		lb t2, (a0)
		lb t3, 1(a0)
		beq t0, t2, CHECK2RL
		addi sp, sp, 4
		lw ra, (sp)
		
		jr ra
	CHECK2RL:
		
		beq t1, t3, WINRL
		addi sp, sp, 4
		lw ra, (sp)
		jr ra
	RESETRL:
		# Jump to start
		# j _start
		# Load the init gamestate.
		 la a0, grid
		 la a1, gridsize
		 jal loadGridState
		 addi sp, sp, 4
		 lw ra, (sp)
		 jr ra
	QUITRL:
		j exit
	CONCEEDRL:
		jal printGrid
		addi sp, sp, 4
		lw ra, (sp)
		jr ra
	WINRL:
		jal printGrid
		addi sp, sp, 4
		lw ra, (sp)
		jr ra
		