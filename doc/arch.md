
# IRRE architecture

this defines the `IRRE` (v1.5) specification.

## introduction

The Irrelevant Utility Architecture (**IRRE**) is a capable, general-purpose machine with a minimalist design that is easy to work with while also being well suited for a variety of computational tasks.

It derives many aspects of its architecture design from the [REGULAR](https://github.com/regular-vm/specification) architecture, notably most of its registers and instruction encoding, and some of its instruction set. For example, IRRE adds several control flow instructions and has different semantics for  the load and store instructions. However, IRRE contains many breaking changes to the REGULAR specification and is neither forwards nor backwards compatible with REGULAR. Despite that, since both architectures share many aspects, porting from REGULAR to IRRE should be fairly straightforward.

The little-endian, 32-bit architecture boasts 37 scalar registers, of which 32 (all but 5 special registers) are available for general purpose use. The instruction set is cleanly designed to simplify unambiguous decoding, and it is kept deliberately minimal to facilitate different programming styles, reduce implementation complexity, and allow for expansion in the future.

## registers

IRRE exposes 37, 32-bit registers to the programmer. The first 32 of these are named sequentially from `r0` to `r31`, all of which are identical and may be used interchangeably and as the argument to any instruction where appropriate.

In addition to these are 5 special registers, comprising a program counter, `pc`, a return address or link register `lr`, two special temporaries `ad` and `at`, and a stack pointer, `sp`.

Registers `r0` to `r31` are encoded using `0x00` to `0x1f`, `pc` is `0x20`, `lr` is `0x21`, `ad` is `0x22`, `at` is `0x23`, and `sp` is `0x24`.

All registers can be read and operated on by instructions; such operations are functionally identical on all registers. However, note that writing to `pc` can alter program flow.

### calling convention (suggested)

To simplify function calls for control flow using a execution stack, it is recommended to implement the interprocedural application binary interface (ABI) as follows:

[WIP]

### instructions

Each IRRE instruction is 32 bits wide. The first byte encodes the opcode, while the remaining three bytes encode register information or immediate values. Register information is encoded in a single byte corresponding to the index of the register in the order specified in the [registers](#registers) section.

For the purposes of instruction encoding, op is the numerical value of the opcode identifying the instruction, rA, rB, rC, … are registers (not necessarily distinct) with the letters standing in for the register's number, and v0, v1, ... are immediate constants embedded in the instruction.

### instruction types

The following are possible encodings for the types of instructions that IRRE supports:

#### op
<table>
	<tr>
		<th>Bit</th>
		<td>0</td>
		<td>1</td>
		<td>2</td>
		<td>3</td>
		<td>4</td>
		<td>5</td>
		<td>6</td>
		<td>7</td>
		<td>8</td>
		<td>9</td>
		<td>10</td>
		<td>11</td>
		<td>12</td>
		<td>13</td>
		<td>14</td>
		<td>15</td>
		<td>16</td>
		<td>17</td>
		<td>18</td>
		<td>19</td>
		<td>20</td>
		<td>21</td>
		<td>22</td>
		<td>23</td>
		<td>24</td>
		<td>25</td>
		<td>26</td>
		<td>27</td>
		<td>28</td>
		<td>29</td>
		<td>30</td>
		<td>31</td>
	</tr>
	<tr>
		<th>Use</th>
		<td colspan="8">op</td>
		<td colspan="24"><i>ignored</i></td>
	</tr>
</table>

#### op rA
<table>
	<tr>
		<th>Bit</th>
		<td>0</td>
		<td>1</td>
		<td>2</td>
		<td>3</td>
		<td>4</td>
		<td>5</td>
		<td>6</td>
		<td>7</td>
		<td>8</td>
		<td>9</td>
		<td>10</td>
		<td>11</td>
		<td>12</td>
		<td>13</td>
		<td>14</td>
		<td>15</td>
		<td>16</td>
		<td>17</td>
		<td>18</td>
		<td>19</td>
		<td>20</td>
		<td>21</td>
		<td>22</td>
		<td>23</td>
		<td>24</td>
		<td>25</td>
		<td>26</td>
		<td>27</td>
		<td>28</td>
		<td>29</td>
		<td>30</td>
		<td>31</td>
	</tr>
	<tr>
		<th>Use</th>
		<td colspan="8">op</td>
		<td colspan="8">A</td>
		<td colspan="16"><i>ignored</i></td>
	</tr>
</table>


#### op v0
<table>
	<tr>
		<th>Bit</th>
		<td>0</td>
		<td>1</td>
		<td>2</td>
		<td>3</td>
		<td>4</td>
		<td>5</td>
		<td>6</td>
		<td>7</td>
		<td>8</td>
		<td>9</td>
		<td>10</td>
		<td>11</td>
		<td>12</td>
		<td>13</td>
		<td>14</td>
		<td>15</td>
		<td>16</td>
		<td>17</td>
		<td>18</td>
		<td>19</td>
		<td>20</td>
		<td>21</td>
		<td>22</td>
		<td>23</td>
		<td>24</td>
		<td>25</td>
		<td>26</td>
		<td>27</td>
		<td>28</td>
		<td>29</td>
		<td>30</td>
		<td>31</td>
	</tr>
	<tr>
		<th>Use</th>
		<td colspan="8">op</td>
		<td colspan="24">v0</td>
	</tr>
</table>

#### op rA v0
<table>
	<tr>
		<th>Bit</th>
		<td>0</td>
		<td>1</td>
		<td>2</td>
		<td>3</td>
		<td>4</td>
		<td>5</td>
		<td>6</td>
		<td>7</td>
		<td>8</td>
		<td>9</td>
		<td>10</td>
		<td>11</td>
		<td>12</td>
		<td>13</td>
		<td>14</td>
		<td>15</td>
		<td>16</td>
		<td>17</td>
		<td>18</td>
		<td>19</td>
		<td>20</td>
		<td>21</td>
		<td>22</td>
		<td>23</td>
		<td>24</td>
		<td>25</td>
		<td>26</td>
		<td>27</td>
		<td>28</td>
		<td>29</td>
		<td>30</td>
		<td>31</td>
	</tr>
	<tr>
		<th>Use</th>
		<td colspan="8">op</td>
		<td colspan="8">A</td>
		<td colspan="16">v0</td>
	</tr>
</table>

#### op rA rB
<table>
	<tr>
		<th>Bit</th>
		<td>0</td>
		<td>1</td>
		<td>2</td>
		<td>3</td>
		<td>4</td>
		<td>5</td>
		<td>6</td>
		<td>7</td>
		<td>8</td>
		<td>9</td>
		<td>10</td>
		<td>11</td>
		<td>12</td>
		<td>13</td>
		<td>14</td>
		<td>15</td>
		<td>16</td>
		<td>17</td>
		<td>18</td>
		<td>19</td>
		<td>20</td>
		<td>21</td>
		<td>22</td>
		<td>23</td>
		<td>24</td>
		<td>25</td>
		<td>26</td>
		<td>27</td>
		<td>28</td>
		<td>29</td>
		<td>30</td>
		<td>31</td>
	</tr>
	<tr>
		<th>Use</th>
		<td colspan="8">op</td>
		<td colspan="8">A</td>
		<td colspan="8">B</td>
		<td colspan="8"><i>ignored</i></td>
	</tr>
</table>

#### op rA rB v0
<table>
	<tr>
		<th>Bit</th>
		<td>0</td>
		<td>1</td>
		<td>2</td>
		<td>3</td>
		<td>4</td>
		<td>5</td>
		<td>6</td>
		<td>7</td>
		<td>8</td>
		<td>9</td>
		<td>10</td>
		<td>11</td>
		<td>12</td>
		<td>13</td>
		<td>14</td>
		<td>15</td>
		<td>16</td>
		<td>17</td>
		<td>18</td>
		<td>19</td>
		<td>20</td>
		<td>21</td>
		<td>22</td>
		<td>23</td>
		<td>24</td>
		<td>25</td>
		<td>26</td>
		<td>27</td>
		<td>28</td>
		<td>29</td>
		<td>30</td>
		<td>31</td>
	</tr>
	<tr>
		<th>Use</th>
		<td colspan="8">op</td>
		<td colspan="8">A</td>
		<td colspan="8">B</td>
		<td colspan="8">v0</td>
	</tr>
</table>

#### op rA v0 v1
<table>
	<tr>
		<th>Bit</th>
		<td>0</td>
		<td>1</td>
		<td>2</td>
		<td>3</td>
		<td>4</td>
		<td>5</td>
		<td>6</td>
		<td>7</td>
		<td>8</td>
		<td>9</td>
		<td>10</td>
		<td>11</td>
		<td>12</td>
		<td>13</td>
		<td>14</td>
		<td>15</td>
		<td>16</td>
		<td>17</td>
		<td>18</td>
		<td>19</td>
		<td>20</td>
		<td>21</td>
		<td>22</td>
		<td>23</td>
		<td>24</td>
		<td>25</td>
		<td>26</td>
		<td>27</td>
		<td>28</td>
		<td>29</td>
		<td>30</td>
		<td>31</td>
	</tr>
	<tr>
		<th>Use</th>
		<td colspan="8">op</td>
		<td colspan="8">A</td>
		<td colspan="8">v0</td>
		<td colspan="8">v1</td>
	</tr>
</table>

#### op rA rB rC
<table>
	<tr>
		<th>Bit</th>
		<td>0</td>
		<td>1</td>
		<td>2</td>
		<td>3</td>
		<td>4</td>
		<td>5</td>
		<td>6</td>
		<td>7</td>
		<td>8</td>
		<td>9</td>
		<td>10</td>
		<td>11</td>
		<td>12</td>
		<td>13</td>
		<td>14</td>
		<td>15</td>
		<td>16</td>
		<td>17</td>
		<td>18</td>
		<td>19</td>
		<td>20</td>
		<td>21</td>
		<td>22</td>
		<td>23</td>
		<td>24</td>
		<td>25</td>
		<td>26</td>
		<td>27</td>
		<td>28</td>
		<td>29</td>
		<td>30</td>
		<td>31</td>
	</tr>
	<tr>
		<th>Use</th>
		<td colspan="8">op</td>
		<td colspan="8">A</td>
		<td colspan="8">B</td>
		<td colspan="8">C</td>
	</tr>
</table>

The bits of each component of these instructions are laid out so that the lower bits of their numerical value corresponds to lower bit numbers for the instruction as a whole.

### instruction set

| Name  | Encoding                      | Description |
|-------|-------------------------------|-------------|
| `nop` | 0x00                          | Perform no operation. |
| `add` | 0x01&nbsp;rA&nbsp;rB&nbsp;rC  | Perform an unsigned 32-bit addition of the values contained in rB and rC and store the result in rA. |
| `sub` | 0x02&nbsp;rA&nbsp;rB&nbsp;rC  | Perform an unsigned 32-bit subtraction of the value contained in rC from the value contained in rB and store the result in rA. |
| `and` | 0x03&nbsp;rA&nbsp;rB&nbsp;rC  | Perform a logical AND operation of the values contained in rB and rC and store the result of the operation in rA. |
| `orr` | 0x04&nbsp;rA&nbsp;rB&nbsp;rC  | Perform a logical OR operation of the values contained in rB and rC and store the result of the operation in rA. |
| `xor` | 0x05&nbsp;rA&nbsp;rB&nbsp;rC  | Perform a logical XOR operation of the values contained in rB and rC and store the result of the operation in rA. |
| `not` | 0x06&nbsp;rA&nbsp;rB          | Perform a logical NOT of the value contained in rB and store the result in rA. |
| `lsh` | 0x07&nbsp;rA&nbsp;rB&nbsp;rC  | Logically shift the value in rB by the number of bits represented by the signed quantity in rC. If this value is positive, shift the value contained in rB left by this many bits; if it is negative the shift will be to the right by the absolute value of the value in rC. In both instances newly vacated bits will be zeroed. If the value in rC is outside of the range (-32, 32) the result is undefined. |
| `ash` | 0x08&nbsp;rA&nbsp;rB&nbsp;rC  | Arithmetically shift the value in rB by the number of bits represented by the signed quantity in rC. If this value is positive, shift the value contained in rB left by this many bits; if it is negative the shift will be to the right by the absolute value of the value in rC. Newly vacated bits will be zeroed in the former case and be a duplicate of the most significant bit in the latter. If the value in rC is outside of the range (-32, 32) the result is undefined. |
| `tcu` | 0x09&nbsp;rA&nbsp;rB&nbsp;rC  | Subtract the unsigned value stored in rC from the unsigned value stored in rB with arbitrary precision and store the sign of the result in rA. |
| `tcs` | 0x0a&nbsp;rA&nbsp;rB&nbsp;rC  | Subtract the signed value stored in rC from the signed value stored in rB with arbitrary precision and store the sign of the result in rA. |
| `set` | 0x0b&nbsp;rA&nbsp;v0         | Store the 16-bit unsigned value v0 into rA. |
| `mov` | 0x0c&nbsp;rA&nbsp;rB          | Copy the value from rB into rA. |
| `ldw` | 0x0d&nbsp;rA&nbsp;rB&nbsp;v0  | Read a 32-bit word from the memory address referred to by rB, signed offset by v0, and store the value into rA. If the address is not word-aligned, the result is implementation-defined. |
| `stw` | 0x0e&nbsp;rA&nbsp;rB&nbsp;v0  | Store the value in rA as a 32-bit value at the memory address referred to by rB, signed offset by v0. If the address is not word-aligned, the result is implementation-defined. |
| `asi` | 0x20&nbsp;rA&nbsp;v0&nbsp;v1  | Left logical shift v0 by v1 bits, then add that quantity to the value stored in rA. If v1 is outside the range (0, 32), the result is undefined. |
| `sup` | 0x21&nbsp;rA&nbsp;v0         | Store the 16-bit unsigned value v0 into the upper 16 bits rA, leaving the lower 16 bits untouched. |
| `hlt` | 0xff         | Halt execution. |
| `int` | 0x71&nbsp;v0         | Raise an interrupt with the 24-bit unsigned code in v0. |
| `jmi` | 0x10&nbsp;v0         | Unconditionally branch to the 24-bit unsigned address in v0. |
| `jmp` | 0x11&nbsp;rA         | Unconditionally branch to the 32-bit unsigned address in rA. |
| `bve` | 0x14&nbsp;rA&nbsp;rB&nbsp;v0         | Conditionally branch to the 32-bit unsigned address in `rA` if the value in `rB` is equal to the value `v0`. |
| `bvn` | 0x15&nbsp;rA&nbsp;rB&nbsp;v0         | Conditionally branch to the 32-bit unsigned address in `rA` if the value in `rB` is not equal to the value `v0`. |
| `cal` | 0x1a&nbsp;rA         | Store the address of the following instruction in `lr` then branch to the 32-bit unsigned address in rA. |
| `ret` | 0x1b         | Branch to the 32-bit unsigned address in `lr`, then set `lr` to `0`. If `lr` already contains `0`, the behavior is implementation-defined. |
| `snd` | 0xfd&nbsp;rA&nbsp;rB&nbsp;rC         | Send command in `rC` to the device identifier in `rB` with argument in `rA`. Result is stored in `rA`. |

To complement this somewhat limited set, most assemblers implement more complex psuedoinstructions built on top of these base instructions by taking advantage of the special temporary registers.
