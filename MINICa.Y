/* Disenho de las reglas de un MINIC */

%{

#include<stdio.h>
#include<ctype.h>
#include<string.h>

int yylex();
typedef union { 
		int entero;
		float real;
		} tipovalor;
void IS(int , int);
char lexema[80];
typedef struct {
		char nombre[30];
		int a1,a2;  	// a1: INT/FLOAT	a2: FUN/VAR
		tipovalor a3; 	// guarda valor
	} tipoTablaSimbolo;

tipoTablaSimbolo TS[100], *pTS;
int nTS = 0;
int insertaSimbolo(char *, int);
int localizaSimbolo(char *);
void muestraSimbolo();
int tipoVar;

// Definicion de la tabla de codigo

typedef struct { int op,a1,a2,a3;}
	tipoCodigo;

tipoCodigo TABCOD[100];
int cx = -1; 		// indice de codigo actual
int indicevartemp = 0;  	//numero de variables temporales
void genCodigo(int ,int ,int ,int );
int genvartemp();
void muestraCodigo();

void interprete();

// Definicion de las operaciones de lenguaje intermedio

#define MOVER	1
#define SUMAR	2
#define SALTAR	3
#define SALTARV	4
#define SALTARF	5

#define MENOR	9
#define MAYOR	10

#define RESTAR       15
#define MULTIPLICAR  16
#define DIVIDIR      17
#define DIVMODULAR   18



%}

%token INT FLOAT FORMATO ID IF ELSE NUM REAL WHILE DO FOR FUNCION
%token LEENUM IMPRINUM IMPRICHAR
%token CENTERO	
%token CFLOAT	
%token VAR
%right '='
%left '?'
%left OR	%left AND	%right NOT
%left IGUAL NOIGUAL MENORIGUAL MAYORIGUAL '<' '>'
%left '+' '-'
%left '*' '/'
%left '%'

%%

	programaC : listaDeclC ;
	listaDeclC : listaDeclC declC | ;
	declC : Tipo listaVar ';';
/*  declC : Tipo ID '('                     listaPar ')' bloque; */
	declC : Tipo ID '(' { IS($1,FUNCION);}	listaPar ')' bloque;
	Tipo : INT  | FLOAT ;
	
/*  listaVar : ID ','                       listaVar | ID ; */
	listaVar : ID ',' { IS(tipoVar,VAR); }	listaVar | ID { IS(tipoVar,VAR); } ;
	listaVar : ID '=' {IS(tipoVar, VAR); $$ = localizaSimbolo(lexema);} expr {genCodigo(MOVER,$3,$4,0);} listaVar2;
	listaVar2 :  | ',' listaVar;
	listaPar : Tipo ID { IS($1,VAR); }',' listaPar   | Tipo ID { IS($1,VAR); } | ;
	bloque : '{' listaVarLoc listaProp '}';
	listaVarLoc : /* Nada */ | Tipo listaVar ';' listaVarLoc ;
	listaProp : listaProp prop | ;
	prop : ';' ;
	prop : bloque ;

	/* prop : IF '(' expr ')' prop ; */
   	/* prop : IF '(' expr ')' {genCodigo(SALTARF,$3,0,-1);
	   						$$ = cx; }
							prop { TABCOD[$5].a3 = cx + 1;}; */

	
	/* prop : IF '(' expr ')' prop ELSE prop ; */
	prop : IF '(' expr ')' {genCodigo(SALTARF,$3,0,-1);
	   						$$ = cx; }
							prop { TABCOD[$5].a3 = cx + 1;}
							ELSE 
							{genCodigo(SALTARV,$3,0,-1);
							$$ = cx;}
							prop { TABCOD[$9].a3 = cx + 1;};

/*  prop : WHILE '('               EXPRESION ')' prop;  */
	prop : WHILE '(' {$$ = cx + 1;}  expr    ')' 	{genCodigo(SALTARF,$4,0,-1); 
	   						                         $$ = cx;} 
				                                 prop	
				                                 	{genCodigo(SALTAR,0,0,$3);
							                         TABCOD[$6].a3 = cx + 1; };
/* 	prop : FOR '(' Tipo listaVar ';' expr ';' expr ')' prop ; */
	prop : FOR '(' Tipo listaVar ';'
				{$$ = cx + 1;} expr { genCodigo(SALTARV,$7,0,-1); $$ = cx;} {genCodigo(SALTARF,$7,0,-1); $$ = cx;} ';'
				{$$ = cx + 1;} listExpr ')'
				{ genCodigo(SALTAR,0,0,$6);
				  TABCOD[$8].a3 = cx + 1; }
				prop
				{genCodigo(SALTAR, 0, 0, $11);
				 TABCOD[$9].a3 = cx + 1;} ;
								
								




/*  prop : IMPRINUM '(' expr ')' ;  */	
	prop : IMPRINUM '(' expr ')' {genCodigo(IMPRINUM,$3,0,0);};
	prop : IMPRICHAR '(' expr ')' {genCodigo(IMPRICHAR,$3,0,0);};
	prop : LEENUM '(' ID ')' { int idx = localizaSimbolo(lexema); genCodigo(LEENUM, idx, 0, 0); } ;
	prop : expr ;

	
	expr : expr OR expr {int n = genvartemp();	genCodigo(OR,n,$1,$3);  $$=n;};
	expr : expr AND expr {int n = genvartemp();	genCodigo(AND,n,$1,$3);  $$=n;};
	expr : NOT expr {int n = genvartemp();	genCodigo(NOT,n,$2,0);  $$=n;};
	expr : expr IGUAL expr {int n = genvartemp();	genCodigo(IGUAL,n,$1,$3);  $$=n;};
	expr : expr NOIGUAL expr {int n = genvartemp();	genCodigo(NOIGUAL,n,$1,$3);  $$=n;};
	expr : expr '<' expr {int n = genvartemp();	genCodigo(MENOR,n,$1,$3);  $$=n;} ;  /* n = $1 < $3   */
	expr : expr '>' expr {int n = genvartemp();	genCodigo(MAYOR,n,$1,$3);  $$=n;} ;
	expr : expr MENORIGUAL expr {int n = genvartemp();	genCodigo(MENORIGUAL,n,$1,$3);  $$=n;} ;
	expr : expr MAYORIGUAL expr {int n = genvartemp();	genCodigo(MAYORIGUAL,n,$1,$3);  $$=n;} ;
	
	expr : expr '+' expr {int n = genvartemp();	genCodigo(SUMAR,n,$1,$3);  $$=n;};
	expr : expr '-' expr {int n = genvartemp(); genCodigo(RESTAR,n,$1,$3);$$=n;} ;
	expr : expr '*' expr {int n = genvartemp(); genCodigo(MULTIPLICAR,n,$1,$3);$$=n;}; 
	expr : expr '/' expr {int n = genvartemp(); genCodigo(DIVIDIR,n,$1,$3);$$=n;} ; 
	expr : expr '%' expr {int n = genvartemp(); genCodigo(DIVMODULAR,n,$1,$3);$$=n;} ;

	expr : expr '?' expr ':' expr ;
	expr : ID {$$ = localizaSimbolo(lexema);};
	expr : NUM  {IS($1,NUM);$$ = localizaSimbolo(lexema);TS[$$].a3.entero = atoi(lexema);};	/* Codigo 1 */
	expr : REAL	{float v; IS($1,REAL);$$ = localizaSimbolo(lexema);	sscanf(lexema,"%f",&v);TS[$$].a3.real = v;};	/* Codigo 2 */
	expr : ID '=' { $$ = localizaSimbolo(lexema); }	expr {genCodigo(MOVER,$3,$4,0);};	/* Codigo 3 */
	expr : ID '[' expr ']' ;
	expr : ID '[' expr ']' '=' expr;

	listExpr  : expr | expr ',' listExpr | ;
%%

void genCodigo(int op,int a1,int a2,int a3)
{
	tipoCodigo *p;

	cx++;
	p = &TABCOD[cx];
	p->op = op;
	p->a1 = a1;
	p->a2 = a2;
	p->a3 = a3;
}

int genvartemp()
{
	char t[30];
	sprintf(t,"_T%-2d",indicevartemp++);
	strcpy(TS[nTS].nombre,t);
	TS[nTS].a1 = VAR;
	return nTS++;
}

void muestraCodigo()
{
	int i,op,a1,a2,a3;
	for(i=0;i<=cx;i++) {
		op = TABCOD[i].op; a1 = TABCOD[i].a1;
		a2 = TABCOD[i].a2; a3 = TABCOD[i].a3;
		printf("%2d) ",i);
		switch(op)
		{
		case SUMAR: printf("SUMAR %s = %s + %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		case MENOR: printf("MENOR %s = %s < %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		case MAYOR: printf("MAYOR %s = %s > %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		case IGUAL: printf("IGUAL %s = %s == %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		case NOIGUAL: printf("NOIGUAL %s = %s != %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		case AND: printf("AND %s = %s && %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		case OR: printf("OR %s = %s || %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		case NOT: printf("NOT %s = ! %s \n",TS[a1].nombre,TS[a2].nombre);break;
		case SALTAR: printf("SALTAR %d \n",a3);break;
		case SALTARV: printf("SALTARV %s %d \n",TS[a1].nombre,a3);break;
		case SALTARF: printf("SALTARF %s %d \n",TS[a1].nombre,a3);break;
		case MOVER: printf("MOVER %s %s \n",TS[a1].nombre,TS[a2].nombre);break;
		case IMPRICHAR: printf("IMPRICHAR %s \n",TS[a1].nombre);break;
		case IMPRINUM: printf("IMPRINUM %s \n",TS[a1].nombre);break;
		case LEENUM: printf("LEENUM %s \n",TS[a1].nombre);break;
		case RESTAR      : printf("RESTAR %s = %s - %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		case MULTIPLICAR : printf("MULTIPLICAR %s = %s * %s\n", TS[a1].nombre,TS[a2].nombre,TS[a3].nombre); break;
		case DIVIDIR     : printf("DIVIDIR %s = %s / %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		case DIVMODULAR : printf("DIVMODULAR %s = %s / %s\n",TS[a1].nombre,TS[a2].nombre,TS[a3].nombre);break;
		
		// Los demas casos
		}
	}
	return;
}


int localizaSimbolo(char *n)
{
	int i;
	for(i=0;i<nTS;i++) if(strcmp(n,TS[i].nombre) == 0) return i;
	return -1;
}

int insertaSimbolo(char *n, int t)
{
	if(localizaSimbolo(n)>=0) return -1;
	strcpy(TS[nTS].nombre,n);
	TS[nTS].a1 = t;
	TS[nTS].a2 = TS[nTS].a3.real = 0;
	return nTS++;	
}

void IS(int tipo,int clase)
{
	int i;
	i = insertaSimbolo(lexema, tipo); 
	TS[i].a2 = clase;
	//printf("*** %d %s\n",tipo,TS[i].nombre);
	//if(i<0) yyerror("Identifiador ya declarado.");
}

void muestraSimbolo()
{
	int i;
	for(i=0,pTS=TS;i<nTS;i++,pTS++)
		printf("%20s %d %d %g\n",pTS->nombre,pTS->a1,pTS->a2,pTS->a3.real);
} 


int yylex()

{
  int c;  char *p;
  do  c=getchar(); while(isspace(c));
  ;
  if (isalpha(c)) {
		p=lexema;
		do  { *p++=c; c=getchar(); } while (isalpha(c));
		ungetc(c,stdin); *p=0;
		if (strcmp(lexema,"if")==0) return IF;
		if (strcmp(lexema,"else")==0) return ELSE;
		if (strcmp(lexema,"int")==0) return tipoVar=yylval=INT;
		if (strcmp(lexema,"float")==0) return tipoVar=yylval=FLOAT;
		if (strcmp(lexema,"while")==0) return WHILE;
		if (strcmp(lexema,"for")==0) return FOR;
		if (strcmp(lexema,"do")==0) return DO;
		if (strcmp(lexema,"print")==0) return IMPRINUM;
		if (strcmp(lexema,"printc")==0) return IMPRICHAR;
		if (strcmp(lexema,"input")==0) return LEENUM;
		if (strcmp(lexema,"chao")==0) return EOF;
		
		/* van otras palabras reservadas */
		
		return yylval=ID;
    }
	/*if (c=='\"') {
		p=lexema;
		do  { *p++=c; c=getchar(); } while (c!='\"');
		ungetc(c,stdin); *p=0;
		return yylval=FORMATO;
    }*/
  
    if ( c=='(' || c==')' || c==';' || c==',' || c=='{' || c=='}' ||
         c==',' || c=='*' || c=='/' || c=='+' || c=='-' || c=='?' ||
         c=='[' || c==']' || c=='%') return yylval=c;

    if ( c=='!') { 
    	c=getchar();
    	if(c=='=') return NOIGUAL;
    	ungetc(c,stdin); return NOT;
    	}
    	
    if ( c=='=' ) {
    	c=getchar();
    	if(c=='=') return IGUAL;
    	ungetc(c,stdin); return '=';
    	}
    	
    if ( c=='>' ) {
    	c=getchar();
    	if(c=='=') return MAYORIGUAL;
    	ungetc(c,stdin); return '>';
    	}
    	
    if ( c=='<' ) {
    	c=getchar();
    	if(c=='=') return MENORIGUAL;
    	ungetc(c,stdin); return '<';
    	}

    if ( c=='&' ) {
    	c=getchar();
    	if(c=='&') return AND;
    	ungetc(c,stdin); return '&';
    }

	if ( c=='|' ) {
    	c=getchar();
    	if(c=='|') return OR;
    	ungetc(c,stdin); return '|';
    }

    if (isdigit(c)) { 
    	p=lexema;
      	do  { *p++=c; c=getchar(); } while (isdigit(c))
      	;
      	if(c=='.') {
			do  { *p++=c; c=getchar(); } while (isdigit(c));
      		ungetc(c,stdin); *p=0; return yylval=REAL;
		}
      	ungetc(c,stdin); *p=0;
    	return yylval=NUM;
    	}
    	
    yyerror("caracter ilegal !!!");
}

yyerror(char *m)  { 
	fprintf(stderr,"error de sintaxis %s\n",m); 
	getchar(); 
	exit(0);
	}

void interprete(){
	int icx,op,a1,a2,a3;
	float v;
	printf("Programa en ejecucion: \n");
	FILE *tty;	
	tty = freopen("/dev/tty", "r", stdin);
	if (tty == NULL) {
		perror("Unable to open terminal for reading");
	}
	icx = 0;
	while(1){
		if(icx==cx+1) break;
		op = TABCOD[icx].op;
		a1 = TABCOD[icx].a1;
		a2 = TABCOD[icx].a2;
		a3 = TABCOD[icx].a3;
		switch(op)
		{
			case SALTAR : icx = a3; continue;
			case SALTARF : 
				if(TS[a1].a3.entero==0) { icx = a3; continue;} break;
			case SALTARV : 
				if(TS[a1].a3.entero==1) { icx = a3; continue;} break;
			case IMPRINUM :
				printf("%8.2f\n",TS[a1].a3.real); break;
			case IMPRICHAR :
				printf("%c\n",(int)(TS[a1].a3.real)); break;
			case LEENUM   : scanf("%f",&TS[a1].a3.real); break;
			case MOVER : TS[a1].a3.real = TS[a2].a3.real; break;

			case OR : TS[a1].a3.entero = (TS[a2].a3.entero || TS[a3].a3.entero); break;
			case AND : TS[a1].a3.entero = (TS[a2].a3.entero && TS[a3].a3.entero); break;
			case NOT : TS[a1].a3.entero = (!TS[a2].a3.entero); break;
			case IGUAL : TS[a1].a3.entero = (TS[a2].a3.real == TS[a3].a3.real); break;
			case NOIGUAL : TS[a1].a3.entero = (TS[a2].a3.real != TS[a3].a3.real); break;
			case MENOR : TS[a1].a3.entero = (TS[a2].a3.real < TS[a3].a3.real); break;
			case MAYOR : TS[a1].a3.entero = (TS[a2].a3.real > TS[a3].a3.real); break;
			case MENORIGUAL : TS[a1].a3.entero = (TS[a2].a3.real <= TS[a3].a3.real); break;
			case MAYORIGUAL : TS[a1].a3.entero = (TS[a2].a3.real >= TS[a3].a3.real); break;


			case SUMAR       : TS[a1].a3.real = TS[a2].a3.real + TS[a3].a3.real; break;
			case RESTAR      : TS[a1].a3.real = TS[a2].a3.real - TS[a3].a3.real; break;
			case MULTIPLICAR : TS[a1].a3.real = TS[a2].a3.real * TS[a3].a3.real; break;
			case DIVIDIR     : TS[a1].a3.real = TS[a2].a3.real / TS[a3].a3.real; break;
			case DIVMODULAR  : TS[a1].a3.real = (int)(TS[a2].a3.real) % (int)(TS[a3].a3.real); break;
		}
		icx++;
	}  //Fin de 'while'
}  //Fin de funcion
	
main(){
	yyparse();
	muestraSimbolo();
	muestraCodigo();
	interprete();
}
