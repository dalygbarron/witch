witch.smc: src/*.inc src/*.asm link.link bin/*
	wla-65816 -o witch.obj src/main.asm
	wlalink -v -S link.link witch.smc

clean:
	rm witch.*