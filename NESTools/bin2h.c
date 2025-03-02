/*
 * Binary to C/ASM converter.
*/

#include <stdio.h>
#include <stdlib.h>

#define ROWLEN      16                      // Byte per string
#define HEX1        "&"                     // HEX numbers prefix (0x0A)
#define HEX2        ""                      // HEX numbers suffix (0Ah)
#define LINEPRE     "    EQUB    "          // Line prefix (usually an assembler directive like DB)

void usage (void)
{
    printf ("bin2h infile\n");
}

int main (int argc, char **argv)
{
    char outname [1024];
    FILE *f, *out;
    int i, read;
    unsigned char readbuf [ROWLEN];

    if (argc <= 1)
    {
        usage ();
        return 1;
    }

    f = fopen (argv[1], "rb");
    if (f == NULL)
    {
        printf ("Cannot open %s\n", argv[1]);
        return 0;
    }

    sprintf (outname, "%s.h", argv[1]);
    out = fopen (outname, "wt");
    if (out == NULL)
    {
        fclose (f);
        printf ("Cannot create %s\n", outname);
        return 0;
    }

    fprintf (out, "This file is generated by bin2h\n\n");

    while (!feof (f))
    {
        read = fread (readbuf, 1, ROWLEN, f);
        fprintf (out, "%s", LINEPRE);
        for (i=0; i<read; i++)
        {
            fprintf (out, HEX1 "%02X" HEX2 ", ", readbuf[i]);
        }
        fprintf (out, "\n");
    }

    fclose (f);
    fclose (out);
    return 1;
}

