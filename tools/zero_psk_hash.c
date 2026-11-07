/* Compute SHA-256(whitebox(PSK)) using the driver's pairing implementation.
 * Used offline to decide whether a sensor holds the all-zero PSK.
 *
 * Build:
 *   cc -O2 -o zero_psk_hash zero_psk_hash.c \
 *      ../../upstream/libfprint-mr648/libfprint/drivers/goodix5125/goodix5125-pairing.c \
 *      $(pkg-config --cflags --libs glib-2.0 openssl)
 */

#include "goodix5125-pairing.h"

#include <glib.h>
#include <stdio.h>
#include <string.h>

int
main (int argc, char **argv)
{
  guint8 psk[GOODIX5125_PSK_SIZE] = { 0 };
  guint8 wb[GOODIX5125_WB_SIZE];
  guint8 hash[GOODIX5125_PSK_SIZE];
  GError *error = NULL;
  guint i;

  if (argc > 1)
    {
      if (strlen (argv[1]) != GOODIX5125_PSK_SIZE * 2)
        {
          fprintf (stderr, "PSK must be 64 hex characters\n");
          return 2;
        }
      for (i = 0; i < GOODIX5125_PSK_SIZE; i++)
        {
          unsigned int byte;
          if (sscanf (argv[1] + i * 2, "%2x", &byte) != 1)
            {
              fprintf (stderr, "Invalid hex at byte %u\n", i);
              return 2;
            }
          psk[i] = (guint8) byte;
        }
    }

  if (!goodix5125_pairing_wrap (psk, wb, &error))
    {
      fprintf (stderr, "wrap failed: %s\n", error ? error->message : "unknown");
      g_clear_error (&error);
      return 1;
    }
  if (!goodix5125_pairing_hash (wb, hash, &error))
    {
      fprintf (stderr, "hash failed: %s\n", error ? error->message : "unknown");
      g_clear_error (&error);
      return 1;
    }

  for (i = 0; i < GOODIX5125_PSK_SIZE; i++)
    printf ("%02x", hash[i]);
  printf ("\n");

  return 0;
}
