def createInputDataFile(quantityOfUsersFromCash, quantityOfUsersToCash, randomKey, cashValue):
	with open("test.c.in", 'w') as file:
		file.write(str(quantityOfUsersFromCash)+'\n')
		file.write(str(quantityOfUsersToCash)+'\n')
		file.write(str(randomKey)+'\n')
		file.write(str(cashValue)+'\n')
