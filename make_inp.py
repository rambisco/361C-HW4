import random
random.seed(a = None, version=2)
f = open("inp.txt", "w+")
for i in range(1000000):
	k = random.randint(0, 999)
	f.write(str(k))
	f.write(",")
f.write("900")

