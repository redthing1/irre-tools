int letters[10];

void load_letters() {
    letters[0] = 'h';  // h
    letters[1] = 'e';  // e
    letters[2] = 'l';  // l
    letters[3] = 'l';  // l
    letters[4] = 'o';  // o
    letters[5] = '\n'; // \n
    letters[6] = 0;
}

int main()
{
    load_letters();

    return letters[0];
}