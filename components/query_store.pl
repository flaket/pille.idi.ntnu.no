/*  Part of ClioPatria SeRQL and SPARQL server

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@cs.vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2010, University of Amsterdam,
		   VU University Amsterdam

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/

:- module(query_store,
	  [ store_recall//2,		% +Type, +ColsStore-CollsRecall
	    query_script//0,		%
	    store_query/3		% +Type, +Id, +Query
	  ]).
:- use_module(library(http/http_session)).
:- use_module(library(http/html_write)).

/** <module> Store/Recall SPARQL queries
*/

%%	store_recall(+Type, +ColsSpec)// is det.

store_recall(Type, SL-SR) -->
	{ next_query_id(Id)
	},
	html(tr([ td([ class(qstore),
		       colspan(SL)
		     ],
		     [ b('Store as: '),
		       input([ id(qid),
			       name(storeAs),
			       size(30),
			       value(Id)
			     ])
		     ]),
		  td([ class(qrecall),
		       colspan(SR),
		       align(right)
		     ],
		     \recall(Type))
		])).


recall(Type) -->
	{ findall(Name-Query, stored_query(Name, Type, Query), Pairs),
	  Pairs \== []
	},
	html([ b('Recall: '),
	       select(name(recall),
		      [ option([selected], '')
		      | \stored_queries(Pairs, 1)
		      ])
	     ]).
recall(_) -->
	[].

:- thread_local
	script_fragment/1.

stored_queries([], _) -->
	[].
stored_queries([Name-Query|T], I) -->
	{ I2 is I + 1,
	  atom_concat(f, I, FName),
	  js_quoted(Query, QuotedQuery),
	  format(atom(Script),
		 'function ~w()\n\
		 { document.query.query.value=\'~w\';\n  \
		   document.getElementById(\'qid\').value="~w";\n\
		 }\n',
		 [ FName, QuotedQuery, Name ]),
	  assert(script_fragment(Script)),
	  format(atom(Call), '~w()', [FName])
	},
	html(option([onClick(Call)], Name)),
	stored_queries(T, I2).

%%	query_script//
%
%	Inserts the <script> holding JavaScript functions that restore
%	the queries.

query_script -->
	{ findall(S, retract(script_fragment(S)), Fragments),
	  Fragments \== []
	}, !,
	[ '\n<script language="JavaScript">\n'
	],
	Fragments,
	[ '\n</script>\n'
	].
query_script -->
	[].

%%	js_quoted(+Raw, -Quoted)
%
%	Quote text for use in JavaScript. Quoted does _not_ include the
%	leading and trailing quotes.

js_quoted(Raw, Quoted) :-
	atom_codes(Raw, Codes),
	phrase(js_quote_codes(Codes), QuotedCodes),
	atom_codes(Quoted, QuotedCodes).

js_quote_codes([]) -->
	[].
js_quote_codes([0'\r,0'\n|T]) --> !,
	"\\n",
	js_quote_codes(T).
js_quote_codes([H|T]) -->
	js_quote_code(H),
	js_quote_codes(T).

js_quote_code(0'') --> !,
	"\\'".
js_quote_code(0'\\) --> !,
	"\\\\".
js_quote_code(0'\n) --> !,
	"\\n".
js_quote_code(0'\r) --> !,
	"\\r".
js_quote_code(0'\t) --> !,
	"\\t".
js_quote_code(C) -->
	[C].

		 /*******************************
		 *	   SAVED QUERIES	*
		 *******************************/

store_query(_, '', _) :- !.
store_query(Type, As, Query) :-
	set_high_id(As),
	http_session_retractall(stored_query(As, Type, _)),
	http_session_retractall(stored_query(_, Type, Query)),
	http_session_asserta(stored_query(As, Type, Query)).

stored_query(As, Type, Query) :-
	http_session_data(stored_query(As, Type, Query)).

set_high_id(Name) :-
	atom_concat('Q-', Id, Name),
	catch(atom_number(Id, N), _, fail), !,
	(   http_session_data(qid(N0))
	->  (   N > N0
	    ->	http_session_retract(qid(_)),
		http_session_assert(qid(N))
	    ;	true
	    )
	;   http_session_assert(qid(N))
	).
set_high_id(_).


next_query_id(Id) :-
	(   http_session_data(qid(Id0))
	->  Next is Id0+1
	;   Next is 1
	),
	atomic_list_concat(['Q-',Next], Id).