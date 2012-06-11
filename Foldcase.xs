#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "unicode/uchar.h"
#include "unicode/ustring.h"

/* iterators require all of these, but most aren't called for our
 * use-cases */

/* Ripped wholesale out of Unicode::ICU::Collator */

static int32_t
byte_getIndex(UCharIterator *i, UCharIteratorOrigin origin) {
  switch(origin) {
  case UITER_START:
    return 0;
  case UITER_CURRENT:
    return i->index;
  case UITER_LIMIT:
    return i->length;
  case UITER_ZERO:
    return 0;
  case UITER_LENGTH:
    return i->length;
  }
}

static int32_t
byte_move(UCharIterator *i, int32_t delta, UCharIteratorOrigin origin) {
  int32_t index = 0;
  switch(origin) {
  case UITER_START:
    index = delta;
    break;
  case UITER_CURRENT:
    index = i->index + delta;
    break;
  case UITER_LIMIT:
    index = i->length + delta;
    break;
  case UITER_ZERO:
    index = delta;
    break;
  case UITER_LENGTH:
    index = i->length + delta;
    break;
  }

  if (index >= 0 && index <= i->length)
    i->index = index;
}

static UBool
byte_hasNext(UCharIterator *i) {
  return i->index < i->length;
}

static UBool
byte_hasPrevious(UCharIterator *i) {
  return i->index > 0;
}

UChar32
byte_current(UCharIterator *i) {
  if(i->index < i->length) {
    unsigned const char *p = i->context;
    return p[i->index];
  }
  return U_SENTINEL;
}

UChar32
byte_next(UCharIterator *i) {
  if(i->index < i->length) {
    unsigned const char *p = i->context;
    return p[i->index++];
  }
  return U_SENTINEL;
}

UChar32
byte_previous(UCharIterator *i) {
  if (i->index > 0) {
    unsigned const char *p = i->context;
    return p[--(i->index)];
  }
  return U_SENTINEL;
}

uint32_t
byte_getState(const UCharIterator *i) {
  return i->index;
}

void
byte_setState(UCharIterator *i, uint32_t state, UErrorCode *status) {
  if (state > i->length) {
    *status = U_INDEX_OUTOFBOUNDS_ERROR;
  }
  else {
    i->index = state;
  }
}

/* Character iterator for byte strings */
static void
uiter_setByteString(UCharIterator *c, char const *src, size_t len) {
  c->context = src;
  c->length = len;
  c->start = 0;
  c->index = 0;
  c->limit = len;
  c->getIndex = byte_getIndex;
  c->move = byte_move;
  c->hasNext = byte_hasNext;
  c->hasPrevious = byte_hasPrevious;
  c->current = byte_current;
  c->next = byte_next;
  c->previous = byte_previous;
  c->getState = byte_getState;
  c->setState = byte_setState;
}

static void *
malloc_temp(pTHX_ size_t size) {
  SV *sv = sv_2mortal(newSV(size));

  return SvPVX(sv);
}

static UChar *
make_uchar(pTHX_ SV *sv, STRLEN *lenp) {
  STRLEN len;
  /* SvPV early to process any GMAGIC */
  char const *pv = SvPV(sv, len);

  if (SvUTF8(sv)) {
    /* room for the characters and a bit for UTF-16 */
    STRLEN src_chars = sv_len_utf8(sv);
    int32_t cap = src_chars * 5 / 4 + 10;
    size_t size = sizeof(UChar) * cap;
    SV *result_sv = sv_2mortal(newSV(size));
    UChar *result = (UChar *)SvPVX(result_sv);
    int32_t result_len;
    UErrorCode status = U_ZERO_ERROR;

    u_strFromUTF8(result, cap, &result_len, pv, len, &status);

    if (status == U_BUFFER_OVERFLOW_ERROR
	|| result_len >= cap) {
      /* need more room, repeat */
      /* ideally this doesn't happen much */
      cap = result_len + 10;
      SvGROW(result_sv, sizeof(UChar) * cap);
      result = (UChar *)SvPVX(result_sv);
      status = U_ZERO_ERROR;
      u_strFromUTF8(result, cap, &result_len, pv, len, &status);
    }

    if (U_SUCCESS(status)) {
      *lenp = result_len;

      return result;
    }
    else {
      croak("Error converting utf8 to utf16: %d", status);
    }
  }
  else {
    UChar *result = malloc_temp(aTHX_ sizeof(UChar) * (len + 1));
    ssize_t i;
    for (i = 0; i < len; ++i)
      result[i] = (unsigned char)pv[i];
    result[len] = 0;
    *lenp = len;

    return result;
  }
}

/*

Convert a UChar * native ICU string into an SV.

Currently this always returns a string with UTF8 on, but that may change.

*/

static SV *
from_uchar(pTHX_ const UChar *src, int32_t len) {
  /* rough guess */
  STRLEN bytes = len * 2;
  SV *result = newSV(bytes);
  UErrorCode status = U_ZERO_ERROR;
  int32_t result_len = 0;

  u_strToUTF8(SvPVX(result), SvLEN(result), &result_len, src, len, &status);
  if (status == U_BUFFER_OVERFLOW_ERROR
      || result_len >= SvLEN(result)) {
    /* overflow of some sort, expand it */
    SvGROW(result, result_len + 10);
    status = U_ZERO_ERROR;
    u_strToUTF8(SvPVX(result), SvLEN(result), &result_len, src, len, &status);
  }

  SvCUR_set(result, result_len);
  SvPOK_only(result);
  *SvEND(result) = '\0';
  SvUTF8_on(result);

  return result;
}

#define XC_UPPER 0
#define XC_LOWER 1
#define XC_FOLD 2
#define XC_TITLE 3


static SV *
case_xc_loc(pTHX_ int which, SV *in, const char *loc) {
  STRLEN in_len;
  UChar *in_u = make_uchar(aTHX_ in, &in_len);
  STRLEN dest_cap = in_len + in_len / 10 + 10;
  SV *dest_sv = sv_2mortal(newSV(dest_cap * sizeof(UChar)));
  UChar *dest_uc = (UChar *)SvPVX(dest_sv);
  UErrorCode status = U_ZERO_ERROR;
  int32_t dest_len;
  switch (which) {
    case XC_UPPER:
      dest_len = u_strToUpper(dest_uc, dest_cap, in_u, in_len, loc, &status);
      break;

    case XC_LOWER:
      dest_len = u_strToLower(dest_uc, dest_cap, in_u, in_len, loc, &status);
      break;

    case XC_FOLD:
      dest_len = u_strFoldCase(dest_uc, dest_cap, in_u, in_len, U_FOLD_CASE_DEFAULT, &status);
      break;

    case XC_TITLE:
      dest_len = u_strToTitle(dest_uc, dest_cap, in_u, in_len, NULL, loc, &status);
      break;

    default:
      croak("Internal error - unknown alias %d", which);
  }

  if (status == U_BUFFER_OVERFLOW_ERROR
      && dest_len >= dest_cap) {
    /* more room */
    dest_cap = dest_len + 10;
    SvGROW(dest_sv, dest_cap * sizeof(UChar));
    status = U_ZERO_ERROR;
    switch (which) {
      case XC_UPPER:
        dest_len = u_strToUpper(dest_uc, dest_cap, in_u, in_len, loc, &status);
        break;

      case XC_LOWER:
        dest_len = u_strToLower(dest_uc, dest_cap, in_u, in_len, loc, &status);
      	break;

      case XC_FOLD:
        dest_len = u_strFoldCase(dest_uc, dest_cap, in_u, in_len, U_FOLD_CASE_DEFAULT, &status);
      	break;

      case XC_TITLE:
      	 dest_len = u_strToTitle(dest_uc, dest_cap, in_u, in_len, NULL, loc, &status);
      	 break;

      default:
        croak("Internal error - unknown alias %d", which);
    }
  }

  if (!U_SUCCESS(status)) {
    croak("Error upper casing: %d", status);
  }
  return from_uchar(aTHX_ dest_uc, dest_len);
}

static SV *case_xc(pTHX_ int which, SV *in) {
  return case_xc_loc(aTHX_ which, in, "");
}

MODULE = Unicode::ICU::Foldcase PACKAGE = Unicode::ICU::Foldcase PREFIX=case_

SV *
case_uc(in)
  SV *in
  ALIAS:
   lc = XC_LOWER
   fc = XC_FOLD
   tc = XC_TITLE
  PROTOTYPE: _
  CODE:
    RETVAL = case_xc(aTHX_ ix, in);
  OUTPUT:
    RETVAL

SV *
case_uc_loc(in, loc)
  SV *in
  const char *loc
  ALIAS:
   lc_loc = XC_LOWER
   tc_loc = XC_TITLE
  CODE:
    RETVAL = case_xc_loc(aTHX_ ix, in, loc);
  OUTPUT:
    RETVAL

