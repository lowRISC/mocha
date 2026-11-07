/* See LICENSE.SiFive for license details. */
OUTPUT_ARCH( "riscv" )
ENTRY( entry )
SECTIONS
{
    whereto = 0x300;
    . = 0x800;
    .text :
    {
        *(.text)
    }
    _end = .;
}
