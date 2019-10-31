import subprocess
import test_db_script
import time
from create_file import createInputDataFile
import os
import random
import json

# data
transaction=True
# random number to verify that prove takes from user
randomKey = random.randint(0,100)
print(randomKey)
# randomKey = 99
getKey = 0
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

	# create input's data file .c.in with input data and randomKey
	inputData = createInputDataFile(quantityOfUsersFromCash, quantityOfUsersToCash, randomKey, cashValue)
	#start program arith r1cs prove verif 
	# startProgram = subprocess.Popen(["clang-7", "-DISEKAI_C_PARSER=0", "-O0", "-c", "-emit-llvm", "test.c"],stdout=subprocess.PIPE)
	# startProgram1 = subprocess.Popen(["./isekai","--scheme=dalek", "--arith=test.arith", "test.bc"],stdout=subprocess.PIPE)
	# startProgram2 = subprocess.Popen(["./isekai","--scheme=dalek", "--arith=test.arith", "test.bc"],stdout=subprocess.PIPE)
	# startProgram3 = subprocess.Popen(["./isekai","--scheme=dalek", "--arith=test.arith", "test.bc"],stdout=subprocess.PIPE)
	# startProgram4 = subprocess.Popen(["./isekai","--scheme=dalek", "--arith=test.arith", "test.bc"],stdout=subprocess.PIPE)

	output1 = subprocess.check_output(["./isekai", "--scheme=dalek", "--r1cs=test.j1", "test.c"])
	output  = subprocess.check_output(["./isekai", "--scheme=dalek", "--prove=testprove", "test.j1"])
	output2 = subprocess.check_output(["./isekai", "--scheme=dalek", "--verif=testprove", "test.j1"])

	# output, err = startProgram3.communicate()
	output = output.decode('utf-8')
	lines = output.split('\n')
	# for i in range(len(lines)):
	# 	print(i, "is number     ", lines[i])
	# print(lines)
	# proveCheck = "* The verification result2 is: PASS"
	proveCheck = "verification SUCCESS"
	proveStatus = lines[len(lines)-4]
	print("proveStatus is ", proveStatus)
	if proveStatus==proveCheck:
	
		# get new cash value
		file = open("test.j1.in","r")
		stringOut = "outputs"

		# data = json.loads(list(file)[1])

		# print(data)
		# here find output data


		for line in file:
			start = line.find(stringOut)
			if start== -1:
				pass
			else:
				out = line[start:]
				outputl1 = out.find("[") 
				outputl2 = out.find("]")
				array = out[outputl1+1:outputl2].split(",")
				listr = list(out[outputl1+1:outputl2].split(","))
				print("This is prove output data", listr	)
				# check that output data is correct 
				if (int(listr[0]) or int(listr[1])) >=0:
					quantityOfUsersFromCash = listr[0]
					quantityOfUsersToCash =listr[1]
					getkey=0
					getKey = listr[2]
					print("NEW first  user cash is: ",quantityOfUsersFromCash)
					print("NEW second user cash is: ",quantityOfUsersToCash)
					print("this is a random key:    ",randomKey)
					print("this is a get key:       ", getKey)



				else:
					transaction=False
		file.close()
		
		# make update for db(this part actually work with stark)
		# if prove success than update db
	
		if int(getKey)==randomKey:
			print(getKey, " getKey is the same as randomKey", randomKey, "the proof takes from correct user")
			test_db_script.updateDB(quantityOfUsersFromCash, quantityOfUsersToCash, userFromID, userToID, cashID)
		else:
			transaction=False	

	else:
		# if verif failed than back up db after block of trans
		test_db_script.callBackup()
		print("ERROR Can't make this block of transaction in step number", counter)
		break
	if (transaction==False):
		test_db_script.callBackup()
		print("ERROR Can't make this block of transaction ")
		break


# after block of transaction delete backup and print db
test_db_script.deleteBackupData()
test_db_script.printDB()
# os.remove("test.c.in")
# # os.remove("test.arith")
# # os.remove("test.arith.in")
# os.remove("test.j1.in")
# os.remove("test.j1")
# # os.remove("testprove.s")
# os.remove("testprove.p")

print("time", "--- %s seconds ---" % (time.time() - startTime))
