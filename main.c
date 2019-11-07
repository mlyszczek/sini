/* ==========================================================================
    Licensed under BSD 2clause license See LICENSE file for more information
    Author: Michał Łyszczek <michal.lyszczek@bofc.pl>
   ==========================================================================
          _               __            __         ____ _  __
         (_)____   _____ / /__  __ ____/ /___     / __/(_)/ /___   _____
        / // __ \ / ___// // / / // __  // _ \   / /_ / // // _ \ / ___/
       / // / / // /__ / // /_/ // /_/ //  __/  / __// // //  __/(__  )
      /_//_/ /_/ \___//_/ \__,_/ \__,_/ \___/  /_/  /_//_/ \___//____/

   ========================================================================== */


#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <limits.h>

/* ==========================================================================
          __             __                     __   _
     ____/ /___   _____ / /____ _ _____ ____ _ / /_ (_)____   ____   _____
    / __  // _ \ / ___// // __ `// ___// __ `// __// // __ \ / __ \ / ___/
   / /_/ //  __// /__ / // /_/ // /   / /_/ // /_ / // /_/ // / / /(__  )
   \__,_/ \___/ \___//_/ \__,_//_/    \__,_/ \__//_/ \____//_/ /_//____/

   ========================================================================== */


#define die(S) do {      fprintf(stderr, S "\n"); exit(1); } while (0)
#define ret(S) do {      fprintf(stderr, S "\n"); return -1; } while (0)
#define goto(S, L) do {  fprintf(stderr, S "\n"); goto L; } while (0)
#define diep(S) do {     perror(S); exit(1); } while (0)
#define retp(S) do {     perror(S); return -1; } while (0)
#define gotop(S, L) do { perror(S); goto L; } while (0)

#define STRINGIFY(X) #X
#define NSTR(N) STRINGIFY(N)

#ifndef LINE_MAX
#	define LINE_MAX 4096
#endif

#ifndef SINI_VERSION
#	define SINI_VERSION "9999"
#endif



#define ACTION_GET 0
#define ACTION_SET 1


/* these are data gather from command line arguments */

static char  *g_file;     /* ini file to operate on */
static char  *g_section;  /* ini section to operate on */
static char  *g_name;     /* ini name to operate on */
static char  *g_value;    /* value to store to ini */


/* ==========================================================================
               ____                     __   _
              / __/__  __ ____   _____ / /_ (_)____   ____   _____
             / /_ / / / // __ \ / ___// __// // __ \ / __ \ / ___/
            / __// /_/ // / / // /__ / /_ / // /_/ // / / /(__  )
           /_/   \__,_//_/ /_/ \___/ \__//_/ \____//_/ /_//____/

   ========================================================================== */


/* ==========================================================================
    It obviously prints help message.
   ========================================================================== */


static void print_usage(void)
{
	printf(
"sini - shell ini file manipulator\n"
"\n"
"Usage: sini [ -h | -v ]\n"
"            [get] [<file>] <object> \n"
"            set [<file>] <object> <value>\n"
"\n"
"  get       get <object> from <file>, used by defaul if not specified\n"
"  set       set <value> in <object> in <file> in non-destructive way\n"
"  file      ini file to manipulate on, optional when SINI_FILE envvar is set\n"
"  object    ini object in format section.name, .name for no section\n"
"  value     value to store in <file>, put in file as-is\n"
"\n");
	printf(
"examples:\n"
"\n"
"  sini get config.ini server.ip\n"
"  sini config.ini \"section space.and name\"\n"
"  sini /etc/config.ini .user\n"
"  SINI_FILE=config.ini sini .ip\n"
"\n"
"  sini set config.ini server.ip 10.1.1.3\n"
"  sini set config.ini \"section space.and name\" \"value with spaces\"\n");
}

/* ==========================================================================
    Generates random alphanumeric data into 's'. 'l' number of bytes will
    be generated, including last '\0' terminator. So when l is 7, 6 random
    bytes will be stored into 's' and one '\0' at the end.
   ========================================================================== */


void random_string
(
	char              *s,  /* generated data will be stored here */
	size_t             l   /* length of the data to generate (with '\0') */
)
{
	static const char  alphanum[] = "0123456789abcdefghijklmnopqrstuvwxyz";
	size_t             i;
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	for (i = 0; i != l; ++i)
		s[i] = alphanum[rand() % (sizeof(alphanum) - 1)];

	s[i - 1] = '\0';
}


/* ==========================================================================
    Splits ini `object' in format `section.name' into two separate valid
    c-strings. `object' should point to modifyable memory, as separator `.'
    character will be changed to '\0'. After success, `g_section' will be
    pointing to begninning of `object' (but dot will be '\0' then), and
    `g_name' will be poiting at first character after dot separator. If
    section is not specified in `object', `g_section' will be NULL.
   ========================================================================== */


static int split_object
(
	char   *object  /* ini object in format `section.name' */
)
{
	char    c;      /* temporary character */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	if (object == NULL)
		return -1;

	if (object[0] == '.')
	{
		/* object without section (global) */
		g_name = object + 1;
		goto end;
	}

	g_section = object;
	while ((c = *object++))
	{
		if (c == '.')
		{
			g_name = object;
			/* replace '.' in object with null, so that section
			 * points to valid c-string
			 */
			object[-1] = '\0';
			goto end;
		}
	}

end:
	/* first character of name should be printable character and
	 * not a space, so object arguments "section." and "section. "
	 * will be invalid. If *name is null, this means there was
	 * no dot separator in object.
	 */
	if (g_name == NULL || !isprint(*g_name) || isspace(*g_name))
		return -1;

	return 0;
}


/* ==========================================================================
    Checks if `line' contains requested `g_section' ini section.

    return
       -1    malformed section, found '[' but not matching ']'
        0    this is not the section we are looking for
        1    yep, this is the section
   ========================================================================== */


static int is_section
(
	char  *line      /* line to check for section */
)
{
	char  *closing;  /* pointer to closing ']' in section */
	int    ret;      /* return code */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	if (*line++ != '[')
		return 0;

	if ((closing = strchr(line, ']')) == NULL)
		ret("unterminated section found, aborting");

	*closing = '\0';
	ret = strcmp(line, g_section) == 0;
	*closing = ']';
	return ret;
}


/* ==========================================================================
    Checks if `line' contains requested `g_name' ini field. If value is
    different than NULL, pointer to field value will be stored there.

    return
       -2    found '[' which starts new section
       -1    error parsing ini file
        0    line does not contain requested line
        1    yes, that line is the line with requested name
   ========================================================================== */


static int is_name
(
	char   *line,  /* line to check for name */
	char  **value  /* pointer to name value will be stored here */
)
{
	char  *delim;  /* points to '=' delimiter */
	char   whites; /* saved whitespace character */
	int    ret;    /* return code */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	/* check if we hit another section */
	if (*line == '[')
		return -2;

	if (*line == '=')
		ret("empty key detected, aborting");

	if ((delim = strchr(line, '=')) == NULL)
		ret("missing '=' in key=value, aborting");

	if (value)
	{
		*value = delim + 1;
		while (isspace(**value)) ++*value;
	}

	while (isspace(delim[-1])) --delim;
	whites = *delim;
	*delim = '\0';
	ret = strcmp(line, g_name) == 0;
	*delim = whites;
	return ret;
}


/* ==========================================================================
    Reads single line from ini file. Full line is stores in location pointed
    by `line' while linelen defines length of `line' buffer. When 0 is
    returned, `*l' will be pointing to first non-whitespace character in
    `line'

    return
       -2    end of file encountered and no data has been read
       -1    line too long to fit into `line' buffer
        0    line read and it is neither comment nor blank line
        1    line read but is unusable per se, it is comment or blank line
   ========================================================================== */


static int get_line
(
	FILE   *f,
	char   *line,
	size_t  linelen,
	char  **l
)
{
	*l = line;
	line[linelen - 1] = 0x7f;

	if (fgets(line, LINE_MAX, f) == NULL)
	{
		if (feof(f))
			return -2;
		retp("error reading ini file");
	}

	if (line[linelen - 1] == '\0' && line[linelen - 2] != '\n')
		ret("line longer than " NSTR(LINE_MAX) ". Sorry.");

	while (isspace(**l)) ++*l;
	/* skip comments and blank lines */
	if (**l == ';' || **l == '\0')
		return 1;

	return 0;
}


/* ==========================================================================
    Reads `g_section'.`g_name' field from `f' file, and prints its value on
    standard output.
   ========================================================================== */


static int do_get
(
	FILE  *f                /* ini file being parsed */
)
{
	char  *l;               /* pointer to line[], for easy manipulation */
	char  *value;           /* pointer to ini value for section.name */
	char   line[LINE_MAX];  /* line from ini file being curently parsed */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	/* we support ini without section, so if section was not set,
	 * go right into name lookup
	 */
	if (g_section == NULL)
		goto got_section;

	/* at first, we need to locate section */
	for (;;)
	{
		switch (get_line(f, line, sizeof(line), &l))
		{
		case -2: return -2;  /* eof */
		case -1: return -1;  /* error */
		case  0: break;      /* valid ini line */
		case  1: continue;   /* empty line or comment */
		}

		switch (is_section(l))
		{
		case -1: return -1;        /* parse error */
		case  1: goto got_section; /* our section found */
		case  0: continue;         /* not it, keep looking */
		}
	}

got_section:
	/* section found. look for name */
	for (;;)
	{
		switch (get_line(f, line, sizeof(line), &l))
		{
		case -2: return -2;  /* eof */
		case -1: return -1;  /* error */
		case  0: break;      /* valid ini line */
		case  1: continue;   /* empty line or comment */
		}

		switch (is_name(l, &value))
		{
		case -2: return -2;  /* another section found, name not found */
		case -1: return -1;  /* parse error */
		case  0: continue;   /* not our name */
		case  1: break;      /* that is our name, print value */
		}

		fputs(value, stdout);
		return 0;
	}
}


/* ==========================================================================
    returns pointer to where basename of `s' starts without modifying source
    `s' pointer.

    Examples:
            path                 basename
            /path/to/file.c      file.c
            path/to/file.c       file.c
            /file.c              file.c
            file.c               file.c
            ""                   ""
            NULL                 segmentation fault
   ========================================================================== */


static const char *basenam
(
	const char  *s      /* string to basename */
)
{
	const char  *base;  /* pointer to base name of path */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

	base = s;

	for (; *s; ++s)
		if (s[0] == '/' && s[1] != '\0')
			base = s + 1;

	return base;
}


/* ==========================================================================
    This function will store random temporary path in `path' in format
    g_file.XXXXXX, where XXXXXX is random string. So for `g_file'
    `../etc/options.ini' path named `../etc/options.ini.XXXXXX' will be
    generated.
   ========================================================================== */


static int gen_tmp_file
(
	char   *path,        /* generated path will be put here */
	size_t  path_size    /* size of `path' buffer */
)
{
	char    tmp_part[8]; /* tmp part of file: XXXXXX */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	if (strlen(g_file) + sizeof(tmp_part) > path_size)
		ret("can't create temp file, path to <file> too large");

	if (strlen(basenam(g_file)) + sizeof(tmp_part) > NAME_MAX)
		ret("can't create temp file, <file> name too large");

	tmp_part[0] = '.';
	random_string(tmp_part + 1, sizeof(tmp_part) - 1);
	sprintf(path, "%s%s", g_file, tmp_part);

	return 0;
}


/* ==========================================================================
    Copies all contents from source `fsrc' file to desctination `fdst'.
    To save some stack memory, reuse memory from upper calls by accepting
    `line' pointer. Stream pointers is not modified in both `fsrc' and
    `fdst', so they can point to arbitrary positions before call.

    returns 0 when
   ========================================================================== */


static int copy_file
(
	FILE   *fsrc,    /* source file */
	FILE   *fdst,    /* destination file */
	char   *line,    /* buffer to use in fgets() */
	size_t  linelen  /* length of `line' buffer */
)
{
	size_t  r;       /* bytes read from fread() */
	size_t  w;       /* bytes written by fwrite() */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	for (;;)
	{
		r = fread(line, 1, linelen, fsrc);
		w = fwrite(line, 1, r, fdst);

		if (w != r)
			retp("failed to write data to temp file");

		if (r != linelen)
		{
			if (feof(fsrc))
				return 0;
			if (ferror(fsrc))
				retp("failed to write data to temp file, failed to read ini");
		}
	}
}


/* ==========================================================================
    Changes specified `g_object' with new `g_value' value. If `g_object'
    does not exist, it will be created.
   ========================================================================== */


static int do_set
(
	FILE  *f  /* ini file being parsed */
)
{
	FILE  *ftmp;            /* temporary file with new ini content */
	char  *l;               /* pointer to line[], for easy manipulation */
	char  *value;           /* pointer to ini value for section.name */
	char   line[LINE_MAX];  /* line from ini file being curently parsed */
	char   tpath[PATH_MAX]; /* path to temporary file */
	int    ret;             /* return code from function */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	ftmp = stdout;
	if (strcmp(g_file, "-"))
	{
		if (gen_tmp_file(tpath, sizeof(tpath)) != 0)
			return -1;

		if ((ftmp = fopen(tpath, "w")) == NULL)
			retp("failed to open temporary data");
	}

	/* we support ini without section, so if section was not set,
	 * go right into name lookup
	 */
	if (g_section == NULL)
		goto got_section;

	/* at first, we need to locate section */
	for (;;)
	{
		switch ((ret = get_line(f, line, sizeof(line), &l)))
		{
		case -2:                    /* eof */
			ret = 0;
			fprintf(ftmp, "[%s]\n%s = %s\n",
					g_section, g_name, g_value);
		case -1: goto end;          /* error */
		case  0: break;             /* valid ini line */
		case  1: fputs(line, ftmp); /* empty line or comment */
		         continue;
		}

		switch ((ret = is_section(l)))
		{
		case -1: goto end;          /* parse error */
		case  1: fputs(line, ftmp); /* our section found */
				 goto got_section;
		case  0: fputs(line, ftmp); /* not it, keep looking */
		         continue;
		}
	}

got_section:
	for (;;)
	{
		switch ((ret = get_line(f, line, sizeof(line), &l)))
		{
		case -2:                    /* eof */
			ret = 0;
			fprintf(ftmp, "%s = %s\n", g_name, g_value);
		case -1: goto end;          /* error */
		case  0: break;             /* valid ini line */
		case  1: fputs(line, ftmp); /* empty line or comment */
		         continue;
		}

		switch (is_name(l, &value))
		{
		case -2:
			/* another section found, name not found, create it */
			fprintf(ftmp, "%s = %s\n", g_name, g_value);
			fputs(line, ftmp);
			ret = copy_file(f, ftmp, line, sizeof(line));
			goto end;

		case  1:
			/* that is our name, print our line, but do not print
			 * old line (value), it's a replacement after all
			 */
			fprintf(ftmp, "%s = %s\n", g_name, g_value);
			ret = copy_file(f, ftmp, line, sizeof(line));
			goto end;

		case -1: ret = -1; goto end;  /* parse error */
		case  0: fputs(line, ftmp);   /* not our name */
		}
	}

end:
	if (ret == 0 && strcmp(g_file, "-"))
		if ((ret = rename(tpath, g_file)))
			perror("do_set(): rename()");

	fclose(ftmp);
	return ret;
}

/* ==========================================================================
                                              _
                           ____ ___   ____ _ (_)____
                          / __ `__ \ / __ `// // __ \
                         / / / / / // /_/ // // / / /
                        /_/ /_/ /_/ \__,_//_//_/ /_/

   ========================================================================== */


int main
(
	int    argc,    /* number of arguments in argv */
	char  *argv[]   /* program arguments from command line */
)
{
	int    action;  /* set or get from ini? */
	int    optind;  /* current option index to parse */
	int    ret;     /* return code from program */
	FILE  *f;       /* ini file to operate on */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	/* ==================================================================
	    Prepare data - parse arguments.
	   ================================================================== */


	if (argc == 1)
		die("no arguments specified, check `sini -h'");

	if (argv[1] && argv[1][0] == '-' && argv[1][1] != '\0')
	{
		if (argv[1][1] == 'h')
			print_usage();
		if (argv[1][1] == 'v')
			printf("sini v" SINI_VERSION "\n"
					"by Michał Łyszczek <michal.lyszczek@bofc.pl>\n");
		return 0;
	}

	/* if action is not specified, use GET by default, then file
	 * will be at index 1
	 */
	optind = 1;
	action = ACTION_GET;
	if (argv[1] && strcmp(argv[1], "get") == 0)
		optind = 2;
	if (argv[1] && strcmp(argv[1], "set") == 0)
	{
		optind = 2;
		action = ACTION_SET;
	}

	if ((g_file = getenv("SINI_FILE")) == NULL)
		if ((g_file = argv[optind++]) == NULL)
			die("file not specified, check `sini -h'");

	if (split_object(argv[optind++]) == -1)
		die("invalid object name, check `sini -h'");

	if (action == ACTION_SET)
		if ((g_value = argv[optind++]) == NULL)
			die("value not specified, check `sini -h'");


	/* ==================================================================
	    Arguments should be parsed and validated by now, so just run
	    requested action.
	   ================================================================== */


	if (strcmp(g_file, "-") == 0)
		f = stdin;

	/* since we do not write to <file> with `set' command (we use
	 * rename(3) so we need write permissions to directory not
	 * file), we still try to open <file> with write access, as it
	 * is not nice to write (or remove and create new in our case)
	 * to a write protected fle
	 */

	else if ((f = fopen(g_file, action == ACTION_SET ? "r+" : "r")) == NULL)
		diep("failed to open <file>");

	srand(time(NULL));
	ret = action == ACTION_SET ? do_set(f) : do_get(f);

	/* we may close stdin here, but that's ok */
	fclose(f);
	return -ret;
}
