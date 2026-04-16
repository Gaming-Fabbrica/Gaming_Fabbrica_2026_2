.PHONY: web clean

web:
	./scripts/build-web.sh

clean:
	rm -rf build
