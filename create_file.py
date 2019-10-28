def createInputDataFile(quantityOfUsersFromCash, quantityOfUsersToCash, cashValue):
	file = open("test.c.in", 'w')
	file.write(str(quantityOfUsersFromCash)+'\n')
	file.write(str(quantityOfUsersToCash)+'\n')
	file.write(str(cashValue)+'\n')
