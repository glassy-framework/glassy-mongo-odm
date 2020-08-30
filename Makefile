test:
	docker-compose -f spec/docker-compose.yml run --rm spec crystal spec $(TARGET_FILE)
