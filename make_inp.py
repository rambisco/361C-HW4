import random
random.seed(a = None, version=2)
f = open("inp.txt", "w+")
f.write("1000000,")
x = [0] * 10;
for i in range(1000000):
	k = random.randint(0, 999)
	x[int(k/100)] += 1
	f.write(str(k))
	f.write(",")
f.write("900")
x[9] += 1

for i in range(10):
	print("x[i]: " + str(x[i]))