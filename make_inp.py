import random
random.seed(a = None, version=2)
f = open("inp.txt", "w+")
f.write("1000000,")
min_num = 1000
for i in range(1000000):
	k = random.randint(100, 999)
	if k < min_num:
		min_num = k
	f.write(str(k))
	f.write(",")
print(min_num)
f.write("900")

