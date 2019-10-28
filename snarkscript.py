import subprocess
import test_db_script
import time
from create_file import createInputDataFile
import os

# data
transaction=True
# start timer for block of transactions
startTime= time.time();
# some start fun to work with db
test_db_script.cleanUpForTesting()
test_db_script.addBackupData()
quantity_transaction = test_db_script.getQuantityTransaction()
# start main loop foreach transactions in block
for counter in range(quantity_transaction):
	print("Now is transaction number ", counter)
	# get data from db about counter's transaction
	dataOfTransaction = test_db_script.getData(counter)
	userFromID = dataOfTransaction[0]
	userToID = dataOfTransaction[1]
	quantityOfUsersFromCash = dataOfTransaction[2]
	quantityOfUsersToCash = dataOfTransaction[3]
	cashValue = dataOfTransaction[4]
	cashID = dataOfTransaction[5]

	# create input's data file .c.in
	inputData = createInputDataFile(quantityOfUsersFromCash, quantityOfUsersToCash, cashValue)
	#start program arith r1cs prove verif 
	startProgram = subprocess.Popen(["clang-7", "-DISEKAI_C_PARSER=0", "-O0", "-c", "-emit-llvm", "test.c"],stdout=subprocess.PIPE)
	startProgram1 = subprocess.Popen(["./isekai", "--arith=test.arith", "test.bc"],stdout=subprocess.PIPE)
	startProgram2 = subprocess.Popen(["./isekai", "--r1cs=test.j1", "test.c", "--scheme=bctv14a"],stdout=subprocess.PIPE)
	startProgram3 = subprocess.Popen(["./isekai", "--prove=testprove", "test.j1", "--scheme=bctv14a"],stdout=subprocess.PIPE)
	startProgram4 = subprocess.Popen(['./isekai', '--verif=testprove', 'test.j1', '--scheme=bctv14a'],stdout=subprocess.PIPE)
	output, err = startProgram3.communicate()
	output = output.decode('utf-8')
	lines = output.split('\n')
	# print(lines)
	proveCheck = "* The verification result2 is: PASS"
	proveStatus = lines[len(lines)-2]
	if proveStatus==proveCheck:
	
		# get new cash value
		file = open("test.j1.in","r")
		stringOut = "outputs"
		for line in file:
			start = line.find(stringOut)
			print(start, "fucking output string")
			if start== -1:
				pass
			else:
				out = line[start:]
				outputl1 = out.find("[") 
				outputl2 = out.find("]")
				array = out[outputl1+1:outputl2].split(",")
				listr = list(out[outputl1+1:outputl2].split(","))
				if (int(listr[0]) or int(listr[1])) >0:
					quantityOfUsersFromCash = listr[0]
					quantityOfUsersToCash =listr[1]
					print(quantityOfUsersFromCash)
					print(quantityOfUsersToCash)
				else:
					transaction=False
		file.close()
		# make update for db(this part actually work with stark)
		# if proive success than update db
		test_db_script.updateDB(quantityOfUsersFromCash, quantityOfUsersToCash, userFromID, userToID, cashID)
		# os.remove("test.arith")
		# os.remove("test.j1")
		# os.remove("test.j1.in")

	else:
		# if verif failed than back up db after block of trans
		test_db_script.callBackup()
		print("ERROR Can't make this block of transaction")
		break
	if (transaction==False):
		test_db_script.callBackup()
		print("ERROR Can't make this block of transaction")
		break


# after block of transaction delete backup and print db
test_db_script.deleteBackupData()
test_db_script.printDB()
print("time", "--- %s seconds ---" % (time.time() - startTime))
