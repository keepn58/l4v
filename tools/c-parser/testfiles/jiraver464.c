int y;

/** DONT_TRANSLATE */
/** MODIFIES: y
    FNSPEC
    f_spec: "\<Gamma> \<turnstile> {s. x_' s < 3} Call f_'proc {s. ret__int_' s < 3}"
*/
int f(int x)
{
  y++;
  return x;
}

int g(int x)
{
  return x + 1;
}
