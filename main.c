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


/* ==========================================================================
          __             __                     __   _
     ____/ /___   _____ / /____ _ _____ ____ _ / /_ (_)____   ____   _____
    / __  // _ \ / ___// // __ `// ___// __ `// __// // __ \ / __ \ / ___/
   / /_/ //  __// /__ / // /_/ // /   / /_/ // /_ / // /_/ // / / /(__  )
   \__,_/ \___/ \___//_/ \__,_//_/    \__,_/ \__//_/ \____//_/ /_//____/

   ========================================================================== */


#define die(S) do { \
		fprintf(stderr, S "\n"); \
		exit(1); \
	} while (0)

#define diep(S) do { \
		perror(S); \
		exit(1); \
	} while (0)

#define ret(S) do { \
		fprintf(stderr, S "\n"); \
		return -1; \
	} while (0)

#define retp(S) do { \
		perror(S); \
		return -1; \
	} while (0)

#define STRINGIFY(X) #X

#ifndef LINE_MAX
#	define LINE_MAX 4096
#endif

#ifndef SINI_VERSION
#	define SINI_VERSION "9999"
#endif

#define LINE_MAX_STR STRINGIFY(LINE_MAX)


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
"\n"
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
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	if (*line++ != '[')
		return 0;

	if ((closing = strchr(line, ']')) == NULL)
		ret("unterminated section found, aborting");

	*closing = '\0';
	if (strcmp(line, g_section))
		return 0;

	return 1;
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
	char  *delim;           /* points to '=' delimiter */
	char  *value;           /* pointer to ini value for section.name */
	char   line[LINE_MAX];  /* line from ini file being curently parsed */
	int    in_section;      /* flag to know if we found requested section */
	/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


	/* if section was not specified, then config names will be on
	 * top of file and in that case we can say we are already
	 * in a section
	 */
	in_section = !g_section;

	for (;;)
	{
		value = NULL;
		line[LINE_MAX - 1] = 0x7f;
		l = line;

		if (fgets(line, LINE_MAX, f) == NULL)
		{
			if (feof(f))
				return -2;
			retp("error reading ini file");
		}

		if (line[LINE_MAX - 1] == '\0' && line[LINE_MAX - 2] != '\n')
			ret("line longer than " LINE_MAX_STR ". Sorry.");

		while (isspace(*l)) ++l;
		/* skip comments and blank lines */
		if (*l == ';' || *l == '\0')
			continue;

		/* at first, we need to locate section */
		if (in_section == 0)
		{
			switch (is_section(l))
			{
				case -1: return -1;
				case  1: in_section = 1;
				case  0: continue;
			}
		}

		/* got matching section, now look for name in that section */
		/* check if we hit another section */
		if (*l == '[')
			return -2;

		if (*l == '=')
			ret("empty key detected, aborting");

		if ((delim = strchr(l, '=')) == NULL)
			ret("missing '=' in key=value, aborting");

		value = delim + 1;
		while (isspace(*value)) ++value;

		while (isspace(delim[-1])) --delim;
		*delim = '\0';

		if (strcmp(l, g_name))
			continue;

		/* value points to valid c-string with value for the
		 * section.name, including '\n' as it points to end
		 * of currently being parsed line.
		 */

		fputs(value, stdout);
		return 0;
	}
}


static int do_set
(
	FILE  *f  /* ini file being parsed */
)
{
	fprintf(stderr, "not yet implemented, sorry:(\n");
	return -1;
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
	else if ((f = fopen(g_file, "r")) == NULL)
		diep("fopen()");

	ret = action == ACTION_SET ? do_set(f) : do_get(f);

	/* we may close stdin here, but that's ok */
	fclose(f);
	return -ret;
}
