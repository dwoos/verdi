default: Makefile.coq
	$(MAKE) -f Makefile.coq

Makefile.coq:
	coq_makefile -R ../../../core "" -R ../../../lib "" -R ../../../systems "" -R ../../../raft "" -R . "" *.v > Makefile.coq

quick: Makefile.coq
	$(MAKE) -f Makefile.coq quick

clean: Makefile.coq
	$(MAKE) -f Makefile.coq clean
	rm -f *.ml *.mli
	rm -rf Makefile.coq
