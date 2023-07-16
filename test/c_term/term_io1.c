#include "../lib/corlib.h"
#include "term.h"

#define MSG_SZ 16 // the size of our message string
#define TERM_MAP_ADDR (char *)0x7000 // the location (changeable) where we map the terminal

char msg1[MSG_SZ] = "writing things\n";
char prompt[MSG_SZ] = "[raw@irre /]$ ";

char read_buf[64];

int main() {
    int ret = 0;
    // map terminal
    volatile char *h_term = TERM_MAP_ADDR;
    term_init(h_term);
    
    // show first mesage
    term_write(h_term, msg1, MSG_SZ);
    term_flush();

    // term_writechar('f');

    int num_read = 0;
    do {
        // write prompt
        term_write(h_term, prompt, MSG_SZ);
        term_flush();
        num_read = term_readln(h_term);

        // copy from terminal buffer to read_buf
        __memcpy(read_buf, h_term, num_read);

        // write to terminal
        // term_writechar('\n');
        term_write(h_term, "(given) ", 16);
        term_flush();
        // write command to terminal
        term_write(h_term, read_buf, num_read);
        term_flush();
    } while (num_read > 1);
    ret = num_read;

    return ret;
}