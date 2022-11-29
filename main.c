#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int json_prettify(const char* json, char* out);

int main(int argc, char* argv[]) {
	if (argc < 2) {
        fprintf(stderr, "Usage: ./%s <json_file>", argv[0]);
		return 1;
	}

	char * buffer = 0;
	long length;
	FILE * f = fopen(argv[1], "rb");
    if (!f) {
        perror("Could not open the file");
        return 1;
    }

	fseek (f, 0, SEEK_END);
    length = ftell (f);
    fseek (f, 0, SEEK_SET);
    buffer = malloc (length+1);
    if (!buffer) {
        fprintf(stderr, "Could not alloc mem\n");
        return 1;
    }
    fread (buffer, 1, length, f);
    fclose (f);
    buffer[length] = '\0';

    // guesstimate, you may need to adopt this for very large files
	char* buf = malloc(length*1024*2);
	int res = json_prettify(buffer, buf);
	if (res) {
		printf("\n\n\n\n");
		printf("-------------------------------------------------\n");
		printf("Error: %d\n", res);
		printf("-------------------------------------------------\n");
		printf("%s\n", buf);
		printf("-------------------------------------------------\n");
		printf("FAIL\n");
		return 1;
	}
	printf("\n\n\n\n");
	printf("-------------------------------------------------\n");
	printf("SUCCESSFUL:\n");
	printf("-------------------------------------------------\n");
	printf("Original String:\n");
	printf("-------------------------------------------------\n");
	printf("%s\n", buffer);
	printf("-------------------------------------------------\n");
	printf("Prettified String:\n");
	printf("-------------------------------------------------\n");
	printf("%s\n", buf);
	printf("-------------------------------------------------\n");
	printf("SUCCESS\n");
	return 0;
}